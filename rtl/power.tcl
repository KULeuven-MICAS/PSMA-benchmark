
# Set the .lib file here
# set LIB_DB       ../lib/..../.lib
# set FULLNAME     ./bit_serial/clk:2.00-1.75-1.50/post
set FULLNAME     ./bit_serial/clk_gate_a_w/clk2.0n-1.75n-1.5n/post
set REPORT       ./bit_serial/clk:2.00-1.75-1.50/post
set DESIGN       L2_mac
set MODE         1111
set CLK_PERIOD   1.50
set VCD          ../sim/dump_${MODE}_clk${CLK_PERIOD}

################# LIBRARY #################

set_attribute library $LIB_DB

################# DESIGN ##################

set_attribute lp_power_analysis_effort high

read_hdl -library work $FULLNAME.v

elaborate top_$DESIGN

############### ANALYZE VCD ###############

read_vcd -static $VCD.vcd

############### REPORT POWER ##############

echo "\n############### POWER - $MODE SUMMARY\nSimulated at $CLK_PERIOD ns clock period.\n" >> $REPORT.rpt
report power -verbose >> $REPORT.rpt

echo "\n############### POWER - $MODE DETAILS\nSimulated at $CLK_PERIOD ns clock period.\n" >> $REPORT.rpt
report power -flat -sort dynamic >> $REPORT.rpt

# Clean-up
delete_obj designs/*