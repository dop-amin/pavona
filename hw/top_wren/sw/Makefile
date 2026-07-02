# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Builds the SRAM-resident ACC smoke firmware for top_wren into a 32-bit VMEM
# that can be backdoor-loaded by the Verilator model via the SramInitFile
# parameter.
#
# Requires a bare-metal RISC-V toolchain (e.g. the one Bazel fetches, or a
# system riscv32-unknown-elf-*) and srec_cat (from the srecord package).
#
# Then run the simulation with the produced VMEM, e.g.:
#   fusesoc --cores-root=. run --target=sim \
#     --SramInitFile=$(pwd)/hw/top_wren/sw/wren_acc_smoke.vmem \
#     lowrisc:systems:chip_wren_verilator
# and expect "wren: ACC PASS" on stdout.

CROSS   ?= riscv32-unknown-elf-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
CFLAGS  := -march=rv32imc_zicsr -mabi=ilp32 -Os -ffreestanding -nostdlib \
           -nostartfiles -Wall -Wextra
LDSCRIPT := wren_sram.ld

all: wren_acc_smoke.vmem

wren_acc_smoke.elf: crt0.S wren_acc_smoke.c $(LDSCRIPT)
	$(CC) $(CFLAGS) -T $(LDSCRIPT) crt0.S wren_acc_smoke.c -o $@

wren_acc_smoke.bin: wren_acc_smoke.elf
	$(OBJCOPY) -O binary $< $@

# 32-bit little-endian words, word-addressed - suitable for $readmemh into the
# prim_ram_1p_adv word array (word 0 == SRAM base 0x1000_0000).
wren_acc_smoke.vmem: wren_acc_smoke.bin
	srec_cat $< -binary -o $@ -vmem 32

clean:
	rm -f wren_acc_smoke.elf wren_acc_smoke.bin wren_acc_smoke.vmem

.PHONY: all clean
