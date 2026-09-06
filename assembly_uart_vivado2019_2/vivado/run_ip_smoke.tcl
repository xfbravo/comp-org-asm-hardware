# Build a clean consumer project from the packaged custom IP and run its smoke test.
set root [file normalize [file join [file dirname [info script]] ..]]
set ip_root [file join $root ip uart_mmio_bridge_1_0]
set work_root [file join $root ip smoke work]
set project_dir [file join $work_root uart_mmio_bridge_smoke]
set project_file [file join $project_dir uart_mmio_bridge_smoke.xpr]
set part xc7a35tcsg324-1

if {![file exists [file join $ip_root component.xml]]} {
    error "Packaged IP not found. Run vivado/package_uart_ip.tcl first."
}

file mkdir $work_root
create_project -force uart_mmio_bridge_smoke $project_dir -part $part
set_property ip_repo_paths [list $ip_root] [current_project]
update_ip_catalog
file mkdir [file join $project_dir ip]

create_ip \
    -name uart_mmio_bridge \
    -vendor bit.edu.cn \
    -library interface \
    -version 1.0 \
    -module_name uart_mmio_bridge_0 \
    -dir [file join $project_dir ip]
set_property -dict [list \
    CONFIG.CLOCK_HZ {1600} \
    CONFIG.BAUD_HZ {100} \
] [get_ips uart_mmio_bridge_0]
generate_target all [get_ips uart_mmio_bridge_0]

# Add the packaged HDL and generated synthesis wrapper explicitly so the
# clean consumer can be synthesized in this process without Vivado launching
# a concurrent dependency run. Keep these synthesis sources out of simulation;
# the IP's generated simulation target supplies them there.
set ip_hdl_files [list \
    [file join $ip_root hdl uart_mmio_bridge.v] \
    [file join $ip_root hdl uart_controller.v] \
]
add_files -fileset sources_1 $ip_hdl_files
set_property used_in_simulation false [get_files $ip_hdl_files]
set synth_wrappers [glob -nocomplain -directory [file join $project_dir ip] */synth/uart_mmio_bridge_0.v]
if {[llength $synth_wrappers] == 0} {
    error "Generated IP synthesis wrapper not found."
}
set synth_wrapper [lindex [lsort -dictionary $synth_wrappers] end]
add_files -fileset sources_1 $synth_wrapper
set_property used_in_simulation false [get_files $synth_wrapper]

add_files -fileset sim_1 [file join $root ip smoke tb_uart_mmio_bridge_ip.v]
add_files -fileset sources_1 [file join $root ip smoke uart_mmio_bridge_consumer.v]
set_property top uart_mmio_bridge_consumer [get_filesets sources_1]
set_property top_auto_set 0 [get_filesets sources_1]
set_property top tb_uart_mmio_bridge_ip [get_filesets sim_1]
set_property top_auto_set 0 [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Synthesize directly in this batch process. Vivado 2019.2 otherwise launches
# the IP dependency run in parallel with synth_1, which is not repeatable on
# all Windows installations.
synth_design -top uart_mmio_bridge_consumer -part $part
puts "IP_SYNTHESIS=COMPLETE"
puts "IP_CONSUMER_SYNTHESIS=COMPLETE"

# Vivado 2019.2 does not expose a STATUS property on IP objects. Successful
# completion of generate_target is the catalog/target-generation check.
puts "IP_CATALOG_STATUS=GENERATED"
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
close_project
puts "IP_SMOKE_PROJECT=$project_file"
