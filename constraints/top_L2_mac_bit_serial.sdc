############## CREATE MODES ###############

create_mode -name {8b_8b 4b_4b 2b_2b 8b_4b 8b_2b}

############### 8-BIT MODE ################

set_constraint_mode 8b_8b
create_clock -name "clk" -period $CLK_8B [get_ports clk]

set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[2]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[0]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[2]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[0]

############### 4-BIT MODE ################

set_constraint_mode 4b_4b
create_clock -name "clk" -period $CLK_4B [get_ports clk]

set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[0]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[0]

for {set i 0} {$i<4} {incr i} {
    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/a_shift_reg[$i]/pins_out/q
}
for {set i 0} {$i<8} {incr i} {
    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/w_shift_reg[[expr {$i+2}]]/pins_out/q
}
#for {set i 14} {$i<20} {incr i} {
#    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
#}

############### 2-BIT MODE ################

set_constraint_mode 2b_2b
create_clock -name "clk" -period $CLK_2B [get_ports clk]

set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[3]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[1]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[0]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[3]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[1]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[0]

for {set i 0} {$i<6} {incr i} {
    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/a_shift_reg[$i]/pins_out/q
}
for {set i 0} {$i<17} {incr i} {
    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/w_shift_reg[[expr {$i+2}]]/pins_out/q
}
#for {set i 12} {$i<20} {incr i} {
#    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
#}

######### WEIGHT-ONLY 4-BIT MODE ##########

set_constraint_mode 8b_4b
create_clock -name "clk" -period $CLK_8B [get_ports clk]

set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[0]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[1]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[0]

for {set i 0} {$i<4} {incr i} {
    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/a_shift_reg[$i]/pins_out/q
    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/w_shift_reg[[expr {$i+2}]]/pins_out/q
}
#for {set i 17} {$i<20} {incr i} {
#    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
#}

######### WEIGHT-ONLY 2-BIT MODE ##########

set_constraint_mode 8b_2b
create_clock -name "clk" -period $CLK_8B [get_ports clk]

set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/ports_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[1]
set_case_analysis 1 /designs/top_L2_mac/ports_in/prec[0]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[3]
set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[2]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[1]
set_case_analysis 1 /designs/top_L2_mac/instances_hier/mac/pins_in/prec[0]

for {set i 0} {$i<6} {incr i} {
    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/a_shift_reg[$i]/pins_out/q
    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/w_shift_reg[[expr {$i+2}]]/pins_out/q
}
#for {set i 16} {$i<20} {incr i} {
#    set_case_analysis 0 /designs/top_L2_mac/instances_hier/mac/instances_seq/z_reg[$i]/pins_out/q
#}

