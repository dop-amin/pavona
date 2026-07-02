// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Fixed-function stubs for the minimal top_wren design.
//
// These stand in for the entropy chain and the OTP key interface when the
// corresponding real blocks are toggled off. They keep the ACC functional (its
// initial secure wipe blocks on a URND ack, and its scramble controller uses a
// fixed reset-default key) but provide NO cryptographic security. They are only
// intended for the minimal bring-up / functional-test configuration.

`include "prim_assert.sv"

// -----------------------------------------------------------------------------
// EDN responder stub.
//
// Completes the EDN endpoint handshake with zero latency: whenever the endpoint
// asserts a request we return an ack together with a data word. The data word
// is advanced on every ack so that consecutive words differ -- this matters for
// the RND path, whose prim_edn_req instance runs with RepCheck enabled and would
// otherwise flag a (spurious) repetition error. The URND path has no such check.
// -----------------------------------------------------------------------------
module wren_edn_stub (
  input  logic               clk_i,
  input  logic               rst_ni,
  input  edn_pkg::edn_req_t  edn_req_i,
  output edn_pkg::edn_rsp_t  edn_rsp_o
);
  // Free-running value, stepped by an odd (golden-ratio) increment on each ack so
  // that no two consecutive delivered words are identical.
  logic [31:0] data_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      data_q <= 32'hD3AD_B33F;
    end else if (edn_req_i.edn_req) begin
      data_q <= data_q + 32'h9E37_79B9;
    end
  end

  always_comb begin
    edn_rsp_o          = edn_pkg::EDN_RSP_DEFAULT;
    edn_rsp_o.edn_ack  = edn_req_i.edn_req;
    edn_rsp_o.edn_fips = 1'b1;
    edn_rsp_o.edn_bus  = data_q;
  end
endmodule

// -----------------------------------------------------------------------------
// ACC OTP scramble-key responder stub.
//
// The ACC has a valid scramble key from reset (RndCnstAccKey*), so this is only
// exercised when software explicitly triggers a memory secure-wipe / rekey. We
// ack the request and hand back the same reset-default key so a rekey is a
// no-op. Purely combinational: ack simply follows req.
// -----------------------------------------------------------------------------
module wren_acc_otp_key_stub (
  input  otp_ctrl_pkg::acc_otp_key_req_t acc_otp_key_req_i,
  output otp_ctrl_pkg::acc_otp_key_rsp_t acc_otp_key_rsp_o
);
  always_comb begin
    acc_otp_key_rsp_o            = '0;
    acc_otp_key_rsp_o.ack        = acc_otp_key_req_i.req;
    acc_otp_key_rsp_o.key        = acc_pkg::RndCnstAccKeyDefault;
    acc_otp_key_rsp_o.nonce      = acc_pkg::RndCnstAccNonceDefault;
    acc_otp_key_rsp_o.seed_valid = 1'b1;
  end
endmodule
