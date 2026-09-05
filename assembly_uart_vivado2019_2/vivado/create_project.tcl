# Vivado 2019.2 project generator. Run from this directory with:
# vivado -mode batch -source vivado/create_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set proj_dir [file join $root vivado]
file mkdir $proj_dir
create_project asm_uart_2019_2 $proj_dir -part xc7a35tcsg324-1 -force
set rtl_files [glob -nocomplain [file join $root rtl *.v]]
add_files -fileset sources_1 $rtl_files
add_files -fileset sources_1 [file join $root rtl cpu_defs.vh]
set_property file_type {Verilog Header} [get_files [file join $root rtl cpu_defs.vh]]
add_files -fileset sources_1 [file join $root mem hello_uart.mem]
set_property file_type {Memory File} [get_files [file join $root mem hello_uart.mem]]
set_property used_in_synthesis true [get_files [file join $root mem hello_uart.mem]]
set_property used_in_simulation true [get_files [file join $root mem hello_uart.mem]]
add_files -fileset sources_1 [file join $root mem echo_uart.mem]
set_property file_type {Memory File} [get_files [file join $root mem echo_uart.mem]]
set_property used_in_simulation true [get_files [file join $root mem echo_uart.mem]]
add_files -fileset constrs_1 [file join $root constr board_338_uart.xdc]
set_property top asm_board_top [current_fileset]
set_property top_auto_set 0 [current_fileset]
add_files -fileset sim_1 [glob -nocomplain [file join $root sim *.v]]
set_property top tb_cpu_uart [get_filesets sim_1]
set_property top_auto_set 0 [get_filesets sim_1]
set_property include_dirs [list [file join $root rtl]] [get_filesets sources_1]
set_property include_dirs [list [file join $root rtl]] [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PROJECT_PATH=[file normalize [file join $proj_dir asm_uart_2019_2.xpr]]"
close_project
