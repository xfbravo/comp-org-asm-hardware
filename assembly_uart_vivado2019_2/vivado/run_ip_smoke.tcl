if {![regexp {^2019\.2(?:\.|$)} [version -short]]} {error "Vivado 2019.2 required"}
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

# Synthesize generated catalog sources in-context; do not duplicate IP sub-design files.
set_property generate_synth_checkpoint false [get_files -all *.xci]

add_files -fileset sim_1 [file join $root ip smoke tb_uart_mmio_bridge_ip.v]
add_files -fileset sources_1 [file join $root ip smoke uart_mmio_bridge_consumer.v]
set_property top uart_mmio_bridge_consumer [get_filesets sources_1]
set_property top_auto_set 0 [get_filesets sources_1]
# The consumer is independently synthesized from the packaged catalog IP.
# A simulation-only, renamed snapshot of system RTL checks every visible output.
set reference_files {}
foreach source_file {uart_controller.v uart_mmio_bridge.v} {
    set f [open [file join $root rtl $source_file] r]
    set source_text [read $f]
    close $f
    set ref_file [file join $work_root reference_$source_file]
    set f [open $ref_file w]
    puts -nonewline $f [string map {uart_mmio_bridge reference_uart_mmio_bridge uart_controller reference_uart_controller} $source_text]
    close $f
    lappend reference_files $ref_file
}
add_files -fileset sim_1 $reference_files
set_property include_dirs [list [file join $root sim]] [get_filesets sim_1]
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
