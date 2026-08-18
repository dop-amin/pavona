/* Copyright zeroRISC Inc & MPI-SP. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Same failure with the macro never invoked -- fails at definition time. */
.macro double_xor a, b
    bn.xor \a, \a, \b
.endm

.section .text.start

main:
    ecall
