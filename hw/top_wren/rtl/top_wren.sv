// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// top_wren: a minimal, ACC-centric top-level design.
//
// Purpose: expose the Asymmetric Cryptographic Coprocessor (ACC) with just
// enough infrastructure to load and run firmware on it. Everything that is not
// required to run code on the ACC is either omitted or replaced by a
// fixed-function stub, selectable via the *En parameters below.
//
// v1 scope (this file):
//   REAL   : rv_core_ibex, acc, a plain code+data SRAM, rv_dm (+JTAG), one uart,
//            and a hand-written TL-UL socket fabric (socket_m1 -> socket_1n).
//   STUBBED: the entropy chain (a responding EDN stub feeds the ACC), the ACC
//            OTP scramble-key interface (fixed reset-default key), the key
//            manager sideload key, the KMAC application interface, life cycle
//            and alerts.
//
// The optional real blocks (real KMAC + AccPQCEn=1 for PQC, the real
// entropy_src/csrng/edn chain, keymgr, otp_ctrl, lc_ctrl, alert_handler) are
// intended to be added behind the *En parameters as follow-ups; v1 supports the
// stub configuration only and enforces this with an assertion.
//
// Deviation from the original plan: the code/data memory is a plain
// (unscrambled) SRAM built from tlul_adapter_sram + prim_ram_1p_adv rather than
// a full sram_ctrl. This is the "drastically more simplistic" option: it lets
// firmware be backdoor-loaded via a plain VMEM in simulation and enables
// instruction fetch unconditionally, avoiding the sram_ctrl EXEC-CSR /
// scramble-key bring-up sequence. A real sram_ctrl can be slotted in later.

`include "prim_assert.sv"

module top_wren
  import top_wren_pkg::*;
#(
  // Backdoor init image for the code/data SRAM (VMEM). Empty => uninitialized.
  parameter                 SramInitFile = "",
  // Enable ACC post-quantum (ML-KEM / ML-DSA) acceleration. Requires the real
  // KMAC block (KmacEn), so it must remain 0 while KMAC is stubbed.
  parameter bit             AccPQCEn     = 1'b0,
  // Optional-block toggles. v1 wires the stub path only; the real branches are
  // follow-up work. Leave at 0.
  parameter bit             EdnEn        = 1'b0,
  parameter bit             KmacEn       = 1'b0,
  parameter bit             KeymgrEn     = 1'b0,
  parameter bit             OtpEn        = 1'b0
) (
  input  logic clk_i,
  input  logic rst_ni,

  // JTAG (rv_dm) - firmware load + debug
  input  jtag_pkg::jtag_req_t jtag_i,
  output jtag_pkg::jtag_rsp_t jtag_o,

  // UART - console
  input  logic uart_rx_i,
  output logic uart_tx_o,
  output logic uart_tx_en_o,

  // ACC alert observability (no alert_handler in this top)
  output prim_alert_pkg::alert_tx_t [acc_reg_pkg::NumAlerts-1:0] acc_alert_tx_o
);

  import tlul_pkg::*;
  import prim_mubi_pkg::*;

  // v1 only supports the all-stub configuration. Enabling a real optional block
  // requires the (not-yet-wired) real instantiation branches.
  `ASSERT_INIT(V1IsStubOnly_A, !(EdnEn | KmacEn | KeymgrEn | OtpEn | AccPQCEn))

  // ---------------------------------------------------------------------------
  // Common enable tie-offs
  // ---------------------------------------------------------------------------
  localparam prim_alert_pkg::alert_rx_t AlertRxTieoff = prim_alert_pkg::ALERT_RX_DEFAULT;

  // ===========================================================================
  // TL-UL fabric: socket_m1 (3 hosts) -> socket_1n (NumDevice devices)
  // ===========================================================================
  tl_h2d_t host_h2d [NumHost];
  tl_d2h_t host_d2h [NumHost];

  tl_h2d_t main_h2d;   // merged host bus
  tl_d2h_t main_d2h;

  tl_h2d_t dev_h2d [NumDevice];
  tl_d2h_t dev_d2h [NumDevice];

  logic [DevSelWidth-1:0] dev_sel;

  // Address decode for the 1:N socket. Out-of-range -> built-in error responder.
  always_comb begin
    dev_sel = DevSelError;
    if       (($unsigned(main_h2d.a_address) & ~SramMask)    == SramBase)    begin
      dev_sel = DevSelWidth'(DevSram);
    end else if (($unsigned(main_h2d.a_address) & ~RvDmMemMask)  == RvDmMemBase)  begin
      dev_sel = DevSelWidth'(DevRvDmMem);
    end else if (($unsigned(main_h2d.a_address) & ~RvDmRegsMask) == RvDmRegsBase) begin
      dev_sel = DevSelWidth'(DevRvDmRegs);
    end else if (($unsigned(main_h2d.a_address) & ~AccMask)      == AccBase)      begin
      dev_sel = DevSelWidth'(DevAcc);
    end else if (($unsigned(main_h2d.a_address) & ~UartMask)     == UartBase)     begin
      dev_sel = DevSelWidth'(DevUart);
    end else if (($unsigned(main_h2d.a_address) & ~IbexCfgMask)  == IbexCfgBase)  begin
      dev_sel = DevSelWidth'(DevIbexCfg);
    end
  end

  tlul_socket_m1 #(
    .M        (NumHost),
    .HReqDepth ({NumHost{4'h0}}),
    .HRspDepth ({NumHost{4'h0}}),
    .DReqDepth (4'h0),
    .DRspDepth (4'h0)
  ) u_socket_m1 (
    .clk_i,
    .rst_ni,
    .tl_h_i (host_h2d),
    .tl_h_o (host_d2h),
    .tl_d_o (main_h2d),
    .tl_d_i (main_d2h)
  );

  tlul_socket_1n #(
    .N            (NumDevice),
    .HReqDepth    (4'h0),
    .HRspDepth    (4'h0),
    .DReqDepth    ({NumDevice{4'h0}}),
    .DRspDepth    ({NumDevice{4'h0}}),
    .ExplicitErrs (1'b1)
  ) u_socket_1n (
    .clk_i,
    .rst_ni,
    .tl_h_i       (main_h2d),
    .tl_h_o       (main_d2h),
    .tl_d_o       (dev_h2d),
    .tl_d_i       (dev_d2h),
    .dev_select_i (dev_sel)
  );

  // ===========================================================================
  // Ibex core
  // ===========================================================================
  logic debug_req;

  rv_core_ibex #(
    // Strip the instruction cache: this removes Ibex's EDN and icache OTP key
    // dependencies (nothing to feed / stub for scramble key refresh).
    .ICache         (1'b0),
    .ICacheScramble (1'b0),
    .PMPEnable      (1'b1),
    .DmBaseAddr     (DmBaseAddr),
    .DmAddrMask     (DmAddrMask),
    .DmHaltAddr     (DmHaltAddr),
    .DmExceptionAddr(DmExceptionAddr)
  ) u_rv_core_ibex (
    .clk_i,
    .rst_ni,
    .clk_edn_i (clk_i),
    .rst_edn_ni(rst_ni),
    .clk_esc_i (clk_i),
    .rst_esc_ni(rst_ni),
    .rst_cpu_n_o(),

    .ram_cfg_icache_tag_i     ('0),
    .ram_cfg_rsp_icache_tag_o (),
    .ram_cfg_icache_data_i    ('0),
    .ram_cfg_rsp_icache_data_o(),

    .hart_id_i  (32'h0),
    .boot_addr_i(BootAddr),

    // Instruction + data host ports
    .corei_tl_h_o(host_h2d[HostIbexInstr]),
    .corei_tl_h_i(host_d2h[HostIbexInstr]),
    .cored_tl_h_o(host_h2d[HostIbexData]),
    .cored_tl_h_i(host_d2h[HostIbexData]),

    .irq_software_i(1'b0),
    .irq_timer_i   (1'b0),
    .irq_external_i(1'b0),

    .esc_tx_i(prim_esc_pkg::ESC_TX_DEFAULT),
    .esc_rx_o(),
    .nmi_wdog_i(1'b0),

    .debug_req_i(debug_req),
    .crash_dump_o(),

    // Release the core straight out of reset (no pwrmgr in this top).
    .lc_cpu_en_i    (lc_ctrl_pkg::On),
    .pwrmgr_cpu_en_i(lc_ctrl_pkg::On),
    .pwrmgr_o       (),

    .scan_rst_ni(1'b1),
    .scanmode_i (prim_mubi_pkg::MuBi4False),

    // Config CSR device port
    .cfg_tl_d_i(dev_h2d[DevIbexCfg]),
    .cfg_tl_d_o(dev_d2h[DevIbexCfg]),

    // ICache disabled: EDN and OTP key are don't-care.
    .edn_o(),
    .edn_i(edn_pkg::EDN_RSP_DEFAULT),
    .clk_otp_i(clk_i),
    .rst_otp_ni(rst_ni),
    .icache_otp_key_o(),
    .icache_otp_key_i(otp_ctrl_pkg::SRAM_OTP_KEY_RSP_DEFAULT),

    .fpga_info_i(32'h0),

    .alert_rx_i({rv_core_ibex_reg_pkg::NumAlerts{AlertRxTieoff}}),
    .alert_tx_o()
  );

  // ===========================================================================
  // Code + data SRAM (plain, unscrambled). ifetch enabled unconditionally.
  // ===========================================================================
  localparam int unsigned SramAw = $clog2(SramSizeWords);

  logic                sram_req;
  logic                sram_we;
  logic [SramAw-1:0]   sram_addr;
  logic [31:0]         sram_wdata;
  logic [31:0]         sram_wmask;
  logic [31:0]         sram_rdata;
  logic                sram_rvalid;
  logic [1:0]          sram_rerror;

  tlul_adapter_sram #(
    .SramAw           (SramAw),
    .SramDw           (32),
    .Outstanding      (2),
    .ByteAccess       (1),
    .ErrOnWrite       (0),
    .ErrOnRead        (0),
    .CmdIntgCheck     (1),  // check command integrity from Ibex
    .EnableRspIntgGen (1),  // generate TL response integrity
    .EnableDataIntgGen(1),  // generate response data integrity (RAM stores raw data)
    .EnableDataIntgPt (0),  // no end-to-end stored integrity
    .SecFifoPtr       (0)
  ) u_sram_adapter (
    .clk_i,
    .rst_ni,
    .tl_i                      (dev_h2d[DevSram]),
    .tl_o                      (dev_d2h[DevSram]),
    .en_ifetch_i               (prim_mubi_pkg::MuBi4True),  // allow execution from SRAM
    .req_o                     (sram_req),
    .req_type_o                (),
    .gnt_i                     (sram_req),                  // single-cycle grant
    .we_o                      (sram_we),
    .addr_o                    (sram_addr),
    .wdata_o                   (sram_wdata),
    .wmask_o                   (sram_wmask),
    .intg_error_o              (),
    .user_rsvd_o               (),
    .rdata_i                   (sram_rdata),
    .rvalid_i                  (sram_rvalid),
    .rerror_i                  (sram_rerror),
    .compound_txn_in_progress_o(),
    .readback_en_i             (prim_mubi_pkg::MuBi4False),
    .readback_error_o          (),
    .wr_collision_i            (1'b0),
    .write_pending_i           (1'b0)
  );

  prim_ram_1p_adv #(
    .Depth          (SramSizeWords),
    .Width          (32),
    .DataBitsPerMask(8),
    .MemInitFile    (SramInitFile),
    .EnableECC      (0),
    .EnableParity   (0)
  ) u_sram (
    .clk_i,
    .rst_ni,
    .req_i    (sram_req),
    .write_i  (sram_we),
    .addr_i   (sram_addr),
    .wdata_i  (sram_wdata),
    .wmask_i  (sram_wmask),
    .rdata_o  (sram_rdata),
    .rvalid_o (sram_rvalid),
    .rerror_o (sram_rerror),
    .cfg_i    ('0),
    .cfg_rsp_o(),
    .alert_o  ()
  );

  // ===========================================================================
  // rv_dm (JTAG debug + system-bus-access host)
  // ===========================================================================
  rv_dm #(
    .IdcodeValue    (32'h0000_0001),
    .UseDmiInterface(1'b0)
  ) u_rv_dm (
    .clk_i,
    .clk_lc_i (clk_i),
    .rst_ni,
    .rst_lc_ni(rst_ni),
    .next_dm_addr_i        (32'h0),
    .lc_hw_debug_clr_i     (lc_ctrl_pkg::Off),
    .lc_hw_debug_en_i      (lc_ctrl_pkg::On),
    .lc_dft_en_i           (lc_ctrl_pkg::Off),
    .pinmux_hw_debug_en_i  (lc_ctrl_pkg::On),
    .lc_check_byp_en_i     (lc_ctrl_pkg::Off),
    .lc_escalate_en_i      (lc_ctrl_pkg::Off),
    .lc_init_done_i        (lc_ctrl_pkg::On),
    .strap_en_i            (1'b0),
    .strap_en_override_i   (1'b0),
    .otp_dis_rv_dm_late_debug_i(prim_mubi_pkg::MuBi8False),
    .scanmode_i            (prim_mubi_pkg::MuBi4False),
    .scan_rst_ni           (1'b1),
    .ndmreset_req_o        (),
    .dmactive_o            (),
    .debug_req_o           (debug_req),
    .unavailable_i         (1'b0),

    .regs_tl_d_i(dev_h2d[DevRvDmRegs]),
    .regs_tl_d_o(dev_d2h[DevRvDmRegs]),
    .mem_tl_d_i (dev_h2d[DevRvDmMem]),
    .mem_tl_d_o (dev_d2h[DevRvDmMem]),
    .sba_tl_h_o (host_h2d[HostRvDmSba]),
    .sba_tl_h_i (host_d2h[HostRvDmSba]),

    .alert_rx_i({rv_dm_reg_pkg::NumAlerts{AlertRxTieoff}}),
    .alert_tx_o(),

    .racl_policies_i(top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o   (),

    .jtag_i,
    .jtag_o,
    .dbg_tl_d_i(tlul_pkg::TL_H2D_DEFAULT),
    .dbg_tl_d_o()
  );

  // ===========================================================================
  // UART (console)
  // ===========================================================================
  uart u_uart (
    .clk_i,
    .rst_ni,
    .tl_i(dev_h2d[DevUart]),
    .tl_o(dev_d2h[DevUart]),
    .alert_rx_i({uart_reg_pkg::NumAlerts{AlertRxTieoff}}),
    .alert_tx_o(),
    .racl_policies_i(top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o   (),
    .lsio_trigger_o (),
    .cio_rx_i   (uart_rx_i),
    .cio_tx_o   (uart_tx_o),
    .cio_tx_en_o(uart_tx_en_o),
    .intr_tx_watermark_o (),
    .intr_tx_empty_o     (),
    .intr_rx_watermark_o (),
    .intr_tx_done_o      (),
    .intr_rx_overflow_o  (),
    .intr_rx_frame_err_o (),
    .intr_rx_break_err_o (),
    .intr_rx_timeout_o   (),
    .intr_rx_parity_err_o()
  );

  // ===========================================================================
  // ACC + its stubbed inter-module partners
  // ===========================================================================
  // Entropy: responding EDN stubs (mandatory - the ACC initial secure wipe
  // blocks on a URND ack).
  edn_pkg::edn_req_t acc_edn_rnd_req, acc_edn_urnd_req;
  edn_pkg::edn_rsp_t acc_edn_rnd_rsp, acc_edn_urnd_rsp;

  wren_edn_stub u_edn_rnd_stub (
    .clk_i,
    .rst_ni,
    .edn_req_i(acc_edn_rnd_req),
    .edn_rsp_o(acc_edn_rnd_rsp)
  );

  wren_edn_stub u_edn_urnd_stub (
    .clk_i,
    .rst_ni,
    .edn_req_i(acc_edn_urnd_req),
    .edn_rsp_o(acc_edn_urnd_rsp)
  );

  // OTP scramble-key responder (fixed reset-default key).
  otp_ctrl_pkg::acc_otp_key_req_t acc_otp_key_req;
  otp_ctrl_pkg::acc_otp_key_rsp_t acc_otp_key_rsp;

  wren_acc_otp_key_stub u_acc_otp_key_stub (
    .acc_otp_key_req_i(acc_otp_key_req),
    .acc_otp_key_rsp_o(acc_otp_key_rsp)
  );

  // ACC alert receiver tie-off (no alert_handler in this top).
  prim_alert_pkg::alert_rx_t [acc_reg_pkg::NumAlerts-1:0] acc_alert_rx;
  assign acc_alert_rx = {acc_reg_pkg::NumAlerts{AlertRxTieoff}};

  acc #(
    .AccPQCEn      (AccPQCEn),
    .RndCnstAccKey  (acc_pkg::RndCnstAccKeyDefault),
    .RndCnstAccNonce(acc_pkg::RndCnstAccNonceDefault)
  ) u_acc (
    .clk_i,
    .rst_ni,

    .tl_i(dev_h2d[DevAcc]),
    .tl_o(dev_d2h[DevAcc]),

    .idle_o(),
    .intr_done_o(),

    .alert_rx_i(acc_alert_rx),
    .alert_tx_o(acc_alert_tx_o),

    .lc_escalate_en_i(lc_ctrl_pkg::Off),
    .lc_rma_req_i    (lc_ctrl_pkg::Off),
    .lc_rma_ack_o    (),

    .ram_cfg_imem_i    ('0),
    .ram_cfg_dmem_i    ('0),
    .ram_cfg_rsp_imem_o(),
    .ram_cfg_rsp_dmem_o(),

    .clk_edn_i (clk_i),
    .rst_edn_ni(rst_ni),
    .edn_rnd_o (acc_edn_rnd_req),
    .edn_rnd_i (acc_edn_rnd_rsp),
    .edn_urnd_o(acc_edn_urnd_req),
    .edn_urnd_i(acc_edn_urnd_rsp),

    .clk_otp_i (clk_i),
    .rst_otp_ni(rst_ni),
    .acc_otp_key_o(acc_otp_key_req),
    .acc_otp_key_i(acc_otp_key_rsp),
    .keymgr_key_i (keymgr_pkg::ACC_KEY_REQ_DEFAULT),

    .kmac_data_o(),
    .kmac_data_i(kmac_pkg::APP_RSP_DEFAULT)
  );

endmodule
