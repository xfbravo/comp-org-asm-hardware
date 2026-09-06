# Package uart_mmio_bridge as a reusable Vivado custom IP.
# Run from Vivado 2019.2 in batch mode or source this file from Tcl.
set root [file normalize [file join [file dirname [info script]] ..]]
set ip_root [file join $root ip uart_mmio_bridge_1_0]
set work_root [file join $root ip packager_work]
set part xc7a35tcsg324-1

file mkdir [file join $ip_root hdl]
file mkdir $work_root

# The packaged source tree is self-contained so a consumer project only needs
# the IP repository; it does not depend on the parent CPU project.
foreach source_file {uart_mmio_bridge.v uart_controller.v} {
    file copy -force [file join $root rtl $source_file] [file join $ip_root hdl $source_file]
}

create_project -force uart_mmio_bridge_packager [file join $work_root project] -part $part
add_files -norecurse [glob -directory [file join $ip_root hdl] *.v]
set_property top uart_mmio_bridge [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project \
    -root_dir $ip_root \
    -vendor bit.edu.cn \
    -library interface \
    -taxonomy /UserIP/Interface_Controllers \
    -import_files

set core [ipx::current_core]
set_property name uart_mmio_bridge $core
set_property version 1.0 $core
set_property display_name {UART MMIO Bridge} $core
set_property description {8N1 UART controller with CPU MMIO registers and seven-segment display output} $core
set_property vendor_display_name {BIT Interface Controllers} $core
set_property company_url {https://www.bit.edu.cn} $core
ipx::save_core $core

set integrity [ipx::check_integrity -quiet $core]
puts "IP_INTEGRITY=$integrity"
puts "IP_COMPONENT=[file normalize [file join $ip_root component.xml]]"
close_project
