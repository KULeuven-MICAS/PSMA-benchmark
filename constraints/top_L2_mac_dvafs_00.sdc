############## CREATE MODES ###############

create_mode -name {8b 4b 2b }

############### 8-BIT MODE ################

set_constraint_mode 8b
create_clock -name "clk" -period $CLK_8B [get_ports clk]

set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[2]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[0]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[2]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[0]

for {set i 20} {$i<32} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}

############### 4-BIT MODE ################

set_constraint_mode 4b
create_clock -name "clk" -period $CLK_4B [get_ports clk]

set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[0]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[0]

for {set i 28} {$i<32} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}
for {set i 12} {$i<16} {incr i} {
	set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
}

############### 2-BIT MODE ################

set_constraint_mode 2b
create_clock -name "clk" -period $CLK_2B [get_ports clk]

set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[3]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[1]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[0]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[3]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[1]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[0]
