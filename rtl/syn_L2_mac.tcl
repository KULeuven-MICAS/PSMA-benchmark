if {[info exists AUTO]} {

    # Auto-mode defines its own parameters
    puts "\033\[41;97;1mAutomatic processing\033\[0m"

} else {
    # Design
    set DESIGN_NAME  bit_separation
    set SDC_MODE     0000
    set DESIGN       top_L2_mac

    # Parameters
    set HEADROOM     4
    set MODE         0000
    set BG           00
    set DVAFS        0            

    # Delays
    set CLK_8B       2.50
    set CLK_4B       2.50
    set CLK_2B       2.50

    # Design Name
    set MAPPING      clk:$CLK_8B-$CLK_4B-$CLK_2B
    set FULLNAME     ${DESIGN_NAME}_$MAPPING

    # Lib - Set the .lib file here
    # set LIB_DB       ../lib/..../.lib

    # Paths 
    set SDC_PATH     ../constraints
    set EXPORT_PATH  ./${DESIGN_NAME}/${MAPPING}
    set RTL_PATH     ../rtl/

    # Reporting
    puts "\033\[41;97;1mManual processing of report\033\[0m"
}

# After setting the module parameters, the module's name becomes ugly
# The next 2 lines are a way to parse the design name into DESIGN_PAR variable
binary scan [binary format B4 $MODE][binary format B4 00$BG] HH MODE_H BG_H
set D_INT ${DESIGN}_HEADROOM${HEADROOM}_MODE4h${MODE_H}_BG2h${BG_H}_DVAFS1h${DVAFS}
# Remove all ' from DInt and save new result to DESIGN_PAR
regsub -all {(.)'} $D_INT {\1} DESIGN_PAR

set_attribute library $LIB_DB

read_hdl -library work -sv $RTL_PATH/helper.sv
read_hdl -library work -sv $RTL_PATH/macro_utils.sv
read_hdl -library work -sv $RTL_PATH/counter.sv
read_hdl -library work -sv $RTL_PATH/mult_2b.sv
read_hdl -library work -sv $RTL_PATH/L1_mult.sv
read_hdl -library work -sv $RTL_PATH/L2_mult.sv
read_hdl -library work -sv $RTL_PATH/L2_mac.sv
read_hdl -library work -sv $RTL_PATH/top_L2_mac.sv

# General compilation settings
set_attribute lp_insert_clock_gating true /
set_attribute syn_global_effort high
set_attribute ungroup true
# set_attribute ungroup false

elaborate -parameters [list $HEADROOM 4'b${MODE} 2'b${BG} 1'b${DVAFS}] $DESIGN
# Rename parameterized design to $DESIGN (won't be needed later)
mv /designs/$DESIGN_PAR $DESIGN
uniquify  $DESIGN

# Clock gating from 2 flip-flops
set_attribute lp_clock_gating_min_flops 2 /designs/*

# set_attribute ungroup_ok true *
set_attribute ungroup_ok false *
# set_attribute ungroup_ok false mac

# SDC version
# Notice that the first echo cmd has ">" instead of ">>", which means it will overwrite any existing report
# Other echo commands append to the new report file, this ensures new synthesis produces new reports
echo "\n############### SDC - CHECK\n"                   >  $EXPORT_PATH/report.rpt
echo "SDC script: $SDC_PATH/${DESIGN}_${SDC_MODE}.sdc"   >> $EXPORT_PATH/report.rpt 

# create_clock -name "clk" -period $CLK_8B [get_ports clk]
redirect -variable RPT_SDC {read_sdc $SDC_PATH/${DESIGN}_${SDC_MODE}.sdc}

echo $RPT_SDC   >> $EXPORT_PATH/report.rpt 

# ungroup /designs/top_L2_mac/instances_hier/mac/L2_mult/* -flatten
syn_generic 
syn_map

write_hdl > ${EXPORT_PATH}/post.v
write_sdf -version 3.0 > ${EXPORT_PATH}/post.sdf

################# REPORTS #################

# Timing reports
echo   "############### TIMING - SUMMARY\n"                >> $EXPORT_PATH/report.rpt
report timing -summary                                     >> $EXPORT_PATH/report.rpt
# Area reports
echo "\n############### AREA - SUMMARY\n"                  >> $EXPORT_PATH/report.rpt
report area                                                >> $EXPORT_PATH/report.rpt
# Clock gating reports
echo   "\n############### CLOCK GATING - SUMMARY\n"        >> $EXPORT_PATH/report.rpt
report clock_gating                                        >> $EXPORT_PATH/report.rpt
# Power reports
echo "\n############### POWER - SUMMARY\n"                 >> $EXPORT_PATH/report.rpt
report power                                               >> $EXPORT_PATH/report.rpt
echo "\n############### GATES - MAC SUMMARY\n"             >> $EXPORT_PATH/report.rpt
report gates -instance_hier mac -power                     >> $EXPORT_PATH/report.rpt
