if {![regexp {^2019\.2(?:\.|$)} [version -short]]} {error "Vivado 2019.2 required"}
set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir [file join $root build]
set f [open [file join $root build tool_version.txt] w]
puts $f [version]
close $f
puts "VIVADO_2019_2_PASS"
