# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Runs late in implementation (route-design post), before the bitstream is
# written. Enables bitstream identification via the USR_ACCESS register, which
# opentitantool reads when loading over the CW310 (`fpga load-bitstream`).
# Without this the load fails with "Command 0x3001a001 not found in bitstream".

# Enable bitstream identification via USR_ACCESS register.
set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
send_msg "wren 1-1" INFO "USR_ACCESS set to TIMESTAMP for bitstream identification."

# Report worst-case timing slack. This is informational for bring-up: it warns
# rather than failing the build so a bitstream is still produced (a design that
# misses timing may be unreliable, so treat a warning here seriously).
set paths [get_timing_paths -delay_type min_max]
if {[llength $paths] > 0} {
  set slack_ns [get_property SLACK [lindex $paths 0]]
  if {$slack_ns < 0} {
    send_msg "wren 1-2" WARNING "Timing NOT met: worst slack ${slack_ns} ns. Bitstream may be unreliable."
  } else {
    send_msg "wren 1-3" INFO "Timing met: worst slack ${slack_ns} ns."
  }
}
