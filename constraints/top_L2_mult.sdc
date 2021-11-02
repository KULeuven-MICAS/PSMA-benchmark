############## CREATE MODES ###############

create_mode -name {8b_8b 4b_4b 2b_2b 8b_4b 8b_2b}

############### 8-BIT MODE ################

set_constraint_mode 8b_8b
create_clock -name "clk" -period $CLK_8B [get_ports clk]

for {set i 20} {$i<128} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}

############### 4-BIT MODE ################

set_constraint_mode 4b_4b
create_clock -name "clk" -period $CLK_4B [get_ports clk]

for {set i 108} {$i<128} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}
for {set i 76} {$i<96} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}
for {set i 44} {$i<64} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}
for {set i 12} {$i<32} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}

############### 2-BIT MODE ################

set_constraint_mode 2b_2b
create_clock -name "clk" -period $CLK_2B [get_ports clk]

######### WEIGHT-ONLY 4-BIT MODE ##########

set_constraint_mode 8b_4b
create_clock -name "clk" -period $CLK_8B [get_ports clk]

for {set i 80} {$i<128} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}
for {set i 16} {$i<64} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}

######### WEIGHT-ONLY 2-BIT MODE ##########

set_constraint_mode 8b_2b
create_clock -name "clk" -period $CLK_8B [get_ports clk]

for {set i 110} {$i<128} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}
for {set i 78} {$i<96} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}
for {set i 46} {$i<64} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}
for {set i 14} {$i<32} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}

