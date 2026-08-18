/* Copyright zeroRISC Inc & MPI-SP. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Fails to assemble: acc_as.py tries to encode \a/\b as literal operands. */
.macro double_xor a, b
    bn.xor \a, \a, \b
    bn.xor \a, \a, \b
.endm

.section .text.start

main:
    double_xor w0, w1
    ecall
