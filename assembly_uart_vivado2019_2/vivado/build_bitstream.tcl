if {![regexp {^2019\.2(?:\.|$)} [version -short]]} {error "Vivado 2019.2 required"}
# Build the board top and save all verification reports under code/build.
set root [file normalize [file join [file dirname [info script]] ..]]
set project_file [file join $root vivado asm_uart_2019_2.xpr]
set report_dir [file join $root build reports]
file mkdir $report_dir

open_project $project_file
set_property top asm_board_top [get_filesets sources_1]
update_compile_order -fileset sources_1

synth_design -top asm_board_top -part xc7a35tcsg324-1
puts "SYNTH_STATUS=Complete"
opt_design
place_design
phys_opt_design
route_design
puts "IMPL_STATUS=Complete"

report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -file [file join $report_dir timing_summary.rpt]
report_timing -delay_type max -max_paths 10 -file [file join $report_dir timing_paths.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
report_io -file [file join $report_dir io.rpt]
check_timing -verbose -file [file join $report_dir check_timing.rpt]

set setup_paths [get_timing_paths -delay_type max -max_paths 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_paths] == 0 || [llength $hold_paths] == 0} {error "Missing timed paths"}
set setup_slack [get_property SLACK [lindex $setup_paths 0]]
set hold_slack [get_property SLACK [lindex $hold_paths 0]]
puts "SETUP_SLACK=$setup_slack"
puts "HOLD_SLACK=$hold_slack"
if {$setup_slack < 0 || $hold_slack < 0} {error "Setup/hold timing failed"}
set timing_check_file [open [file join $report_dir check_timing.rpt] r]
set timing_check_text [read $timing_check_file]
close $timing_check_file
# Vivado 2019.2 prints counts in the section body (not in heading parentheses).
foreach phrase {
    {register/latch pins with no clock}
    {register/latch pins with constant_clock}
    {pins that are not constrained for maximum delay}
    {register/latch pins with multiple clocks}
    {generated clocks that are not connected to a clock source}
    {combinational loops in the design}
    {combinational latch loops in the design}
    {input ports with no input delay specified}
    {ports with no output delay specified}
} {
    set pattern [format {There are ([0-9]+) %s} $phrase]
    if {![regexp $pattern $timing_check_text -> count]} {error "Missing timing coverage count: $phrase"}
    if {$count != 0} {error "Timing coverage failed: $phrase=$count"}
}
if {[get_property PERIOD [get_clocks sys_clk]] != 10.0 ||
    [get_property PERIOD [get_clocks cpu_clk]] != 20.0} {error "Unexpected board/CPU clock period"}
report_clock_utilization -file [file join $report_dir clocks.rpt]
set timing_file [open [file join $report_dir timing_summary.rpt] r]
set timing_text [read $timing_file]
close $timing_file
if {[string first "All user specified timing constraints are met." $timing_text] < 0} {error "Timing summary does not meet all constraints"}
set timing_wns ""
set timing_tns ""
foreach timing_line [split $timing_text "\n"] {
    if {[regexp {^[[:space:]]*([-+0-9.]+)[[:space:]]+([-+0-9.]+)[[:space:]]+[0-9]+[[:space:]]+[0-9]+} $timing_line -> timing_wns timing_tns]} {
        break
    }
}
if {$timing_wns eq ""} {
    error "Could not parse timing summary signoff values."
}
puts "TIMING_WNS=$timing_wns"
puts "TIMING_TNS=$timing_tns"
if {$timing_wns < 0.0 || $timing_tns < 0.0} {
    error "Timing signoff failed: WNS=$timing_wns TNS=$timing_tns"
}

set drc_file [open [file join $report_dir drc.rpt] r]
set drc_text [read $drc_file]
close $drc_file
if {![regexp {Violations found:[[:space:]]+([0-9]+)} $drc_text -> drc_violations]} {
    error "Could not parse DRC signoff value."
}
puts "DRC_VIOLATIONS=$drc_violations"
if {$drc_violations != 0} {
    error "DRC signoff failed: violations=$drc_violations"
}

set routed_checkpoint [file join $root build asm_board_top_routed.dcp]
set bitstream_file [file join $root build asm_board_top.bit]
write_checkpoint -force $routed_checkpoint

# Vivado 2019.2 can terminate while bitgen is launched directly from the
# implementation design. Reopen the routed checkpoint before writing the
# bitstream; this keeps bitgen deterministic without changing the netlist.
close_project
open_checkpoint $routed_checkpoint
write_bitstream -force $bitstream_file

puts "BUILD_REPORT_DIR=$report_dir"
puts "BITSTREAM_PATH=[file normalize $bitstream_file]"
close_design

puts "FINAL_BUILD_PASS"
