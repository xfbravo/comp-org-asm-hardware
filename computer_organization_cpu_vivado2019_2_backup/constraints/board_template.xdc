# Board constraint template.
# Fill PACKAGE_PIN values after the exact FPGA board model and schematic are known.
# All lines are intentionally commented so this file is safe before board selection.

# Clock
# set_property PACKAGE_PIN <CLK_PIN> [get_ports clk]
# set_property IOSTANDARD LVCMOS33 [get_ports clk]
# create_clock -period 10.000 -name sys_clk [get_ports clk]

# Reset
# set_property PACKAGE_PIN <RST_N_PIN> [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# Switches
# set_property PACKAGE_PIN <SW0_PIN> [get_ports {switches[0]}]
# set_property PACKAGE_PIN <SW1_PIN> [get_ports {switches[1]}]
# set_property PACKAGE_PIN <SW2_PIN> [get_ports {switches[2]}]
# set_property PACKAGE_PIN <SW3_PIN> [get_ports {switches[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {switches[*]}]

# LEDs
# set_property PACKAGE_PIN <LED0_PIN> [get_ports {leds[0]}]
# set_property PACKAGE_PIN <LED1_PIN> [get_ports {leds[1]}]
# set_property PACKAGE_PIN <LED2_PIN> [get_ports {leds[2]}]
# set_property PACKAGE_PIN <LED3_PIN> [get_ports {leds[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {leds[*]}]

# Seven-segment display anodes/select lines
# set_property PACKAGE_PIN <SEG_AN0_PIN> [get_ports {seg_an[0]}]
# set_property PACKAGE_PIN <SEG_AN1_PIN> [get_ports {seg_an[1]}]
# set_property PACKAGE_PIN <SEG_AN2_PIN> [get_ports {seg_an[2]}]
# set_property PACKAGE_PIN <SEG_AN3_PIN> [get_ports {seg_an[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {seg_an[*]}]

# Seven-segment display segments
# set_property PACKAGE_PIN <SEG_A_PIN> [get_ports {seg[0]}]
# set_property PACKAGE_PIN <SEG_B_PIN> [get_ports {seg[1]}]
# set_property PACKAGE_PIN <SEG_C_PIN> [get_ports {seg[2]}]
# set_property PACKAGE_PIN <SEG_D_PIN> [get_ports {seg[3]}]
# set_property PACKAGE_PIN <SEG_E_PIN> [get_ports {seg[4]}]
# set_property PACKAGE_PIN <SEG_F_PIN> [get_ports {seg[5]}]
# set_property PACKAGE_PIN <SEG_G_PIN> [get_ports {seg[6]}]
# set_property PACKAGE_PIN <SEG_DP_PIN> [get_ports {seg[7]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {seg[*]}]
