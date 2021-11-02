set BIT_SERIAL 1

if {[info exists AUTO]} {

    # Auto-mode defines its own parameters
    puts "\033\[41;97;1mAutomatic processing\033\[0m"

} else {
    # Parameters
    set HEADROOM     4 
    set L4_MODE      11 
    set L3_MODE      11 
    set L2_MODE      1111
    set BG           11
    set DVAFS        0  
    set DESIGN_NAME  BG_${BG}_L4_${L4_MODE}_L3_${L3_MODE}_L2_${L2_MODE}_DVAFS_${DVAFS}         
    
    # Design
    set SDC_MODE     L4_prec_only
    set DESIGN       top_L4_mac

    # Delays
    set CLK_8B       25.00
    set CLK_4B       25.00
    set CLK_2B       25.00

    # Design Name
    set MAPPING      clk:$CLK_8B-$CLK_4B-$CLK_2B
    set FULLNAME     ${DESIGN_NAME}_$MAPPING

    # Lib - Set the .lib file in here
    # set LIB_DB       ../lib/..../.lib
    # Paths 
    set RTL_PATH     ../rtl/
    set SDC_PATH     ../constraints
    set EXPORT_PATH  ./${DESIGN_NAME}/${MAPPING}
    set REPORT_FILE  ${EXPORT_PATH}/report_syn.rpt

    # Reporting
    puts "\033\[41;97;1mManual processing of report\033\[0m"
}

# After setting the module parameters, the module's name becomes ugly
# The next 2 lines are a way to parse the design name into DESIGN_PAR variable
binary scan [binary format B4 $L2_MODE][binary format B4 00$BG][binary format B4 00$L3_MODE][binary format B4 00$L4_MODE] HHHH L2_MODE_H BG_H L3_MODE_H L4_MODE_H
set D_INT ${DESIGN}_HEADROOM${HEADROOM}_L4_MODE2h${L4_MODE_H}_L3_MODE2h${L3_MODE_H}_L2_MODE4h${L2_MODE_H}_BG2h${BG_H}_DVAFS1h${DVAFS}
# Remove all ' from DInt and save new result to DESIGN_PAR
regsub -all {(.)'} $D_INT {\1} DESIGN_PAR

set_attribute library $LIB_DB

read_hdl -library work -sv $RTL_PATH/helper.sv
read_hdl -library work -sv $RTL_PATH/macro_utils.sv
read_hdl -library work -sv $RTL_PATH/counter.sv
read_hdl -library work -sv $RTL_PATH/mult_2b.sv
if {$BG==11} {
    puts "\033\[41;97;1mDEFINE BIT_SERIAL\033\[0m"
    read_hdl -library work -sv $RTL_PATH/L1_mult.sv    -define BIT_SERIAL
    read_hdl -library work -sv $RTL_PATH/L2_mult.sv    -define BIT_SERIAL 
    read_hdl -library work -sv $RTL_PATH/L3_mult.sv    -define BIT_SERIAL
    read_hdl -library work -sv $RTL_PATH/L4_mult.sv    -define BIT_SERIAL
    read_hdl -library work -sv $RTL_PATH/L4_mac.sv     -define BIT_SERIAL
    read_hdl -library work -sv $RTL_PATH/top_L4_mac.sv -define BIT_SERIAL
} else {
    puts "\033\[41;97;1mDON'T DEFINE BIT_SERIAL\033\[0m"
    read_hdl -library work -sv $RTL_PATH/L1_mult.sv 
    read_hdl -library work -sv $RTL_PATH/L2_mult.sv  
    read_hdl -library work -sv $RTL_PATH/L3_mult.sv 
    read_hdl -library work -sv $RTL_PATH/L4_mult.sv 
    read_hdl -library work -sv $RTL_PATH/L4_mac.sv 
    read_hdl -library work -sv $RTL_PATH/top_L4_mac.sv 
}

# General compilation settings
set_attribute lp_insert_clock_gating true /
set_attribute syn_global_effort high
set_attribute ungroup true
set_attribute hdl_max_loop_limit 4100
set_attribute max_cpus_per_server 8
# set_attribute ungroup false

elaborate -parameters [list $HEADROOM 2'b${L4_MODE} 2'b${L3_MODE} 4'b${L2_MODE} 2'b${BG} 1'b${DVAFS}] $DESIGN
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
echo "\n############### SDC - CHECK\n"                   >  ${REPORT_FILE}
echo "SDC script: $SDC_PATH/${DESIGN}_${SDC_MODE}.sdc"   >> ${REPORT_FILE} 

# create_clock -name "clk" -period $CLK_8B [get_ports clk]
redirect -variable RPT_SDC {read_sdc $SDC_PATH/${SDC_MODE}.sdc}

echo $RPT_SDC   >> ${REPORT_FILE} 

# ungroup /designs/top_L2_mac/instances_hier/mac/L2_mult/* -flatten
syn_generic 
syn_map

write_hdl > ${EXPORT_PATH}/post.v
write_sdf -version 3.0 > ${EXPORT_PATH}/post.sdf

################# REPORTS #################

# Timing reports
echo   "############### TIMING - SUMMARY\n"                >> ${REPORT_FILE}
report timing -summary                                     >> ${REPORT_FILE}
# Area reports
echo "\n############### AREA - SUMMARY\n"                  >> ${REPORT_FILE}
report area                                                >> ${REPORT_FILE}
# Clock gating reports
echo   "\n############### CLOCK GATING - SUMMARY\n"        >> ${REPORT_FILE}
report clock_gating                                        >> ${REPORT_FILE}
# Power reports
echo "\n############### POWER - SUMMARY\n"                 >> ${REPORT_FILE}
report power                                               >> ${REPORT_FILE}
echo "\n############### GATES - MAC SUMMARY\n"             >> ${REPORT_FILE}
report gates -instance_hier L4 -power                      >> ${REPORT_FILE}
