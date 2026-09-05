# Run one behavioral simulation from the command line.
# Usage: vivado -mode batch -source vivado/run_one_sim.tcl -tclargs <top>
set root [file normalize [file join [file dirname [info script]] ..]]
set project_file [file join $root vivado asm_uart_2019_2.xpr]

if {$argc != 1} {
    error "Expected one simulation top name"
}

set sim_top [lindex $argv 0]
open_project $project_file
set requested_tb [file join $root sim ${sim_top}.v]
if {[file exists $requested_tb] && [llength [get_files -quiet $requested_tb]] == 0} {
    add_files -fileset sim_1 $requested_tb
}
set_property top $sim_top [get_filesets sim_1]
set_property top_auto_set 0 [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
set_property top tb_cpu_uart [get_filesets sim_1]
close_project
