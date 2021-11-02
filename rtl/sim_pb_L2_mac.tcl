
if {[info exists AUTO]} {
    # Auto-mode defines its own parameters
    puts "\033\[41;97;1mAutomatic processing\033\[0m"

} else {
    set DESIGN_NAME bit_separation
    # Set the .v file here
    # set LIB_V       ../lib/..../.v
    set EXPORT_PATH ../results/$DESIGN_NAME/clk:2.25-2.00-1.75
    set V_FILE      $EXPORT_PATH/post.v
    set SDF_FILE    $EXPORT_PATH/post.sdf
    set RTL_PATH    ../rtl
    set PB_FILE     $RTL_PATH/pb_L2_mac.sv
    set HELPER      $RTL_PATH/helper.sv
    puts "\033\[41;97;1mManual processing of $V_FILE\033\[0m"
}
    
vlog -quiet $LIB_V
vlog $HELPER $V_FILE $PB_FILE

if {[info exists AUTO]} {

    vsim pb_L2 -t ps \
    -G TEST=$TEST \
    -G PRCSN=4'b${PRECISION} \
    -G CLK_PRD=${CLK_PERIOD}ns \
    -G DVAFS=1'b$DVAFS \
    -G HEADROOM=$HEADROOM \
    -G MODE=4'b$MODE \
    -G BG=2'b$BG \
    -G VCD_FILE=$VCD_FILE \
    -sdfmax genblk1.L2=$SDF_FILE

} else {
    # vsim pb_L2 -t ps \
    #     -G TEST=$TEST \
    #     -G PRCSN=4'b${PRECISION} \
    #     -G CLK_PRD=${CLK_PERIOD}ns \
    #     -G DVAFS=1'b$DVAFS \
    #     -G HEADROOM=$HEADROOM \
    #     -G MODE=4'b$MODE \
    #     -G BG=2'b$BG \
    #     -G VCD_FILE=$VCD_FILE \
    #     -sdfmax genblk1.L2=$SDF_FILE -voptargs=+acc
    vsim pb_L2 -t ps -sdfmax genblk1.L2=$SDF_FILE -voptargs=+acc
    add wave -position insertpoint  \
    sim:/pb_L2/genblk1.L2/clk \
    sim:/pb_L2/genblk1.L2/rst \
    sim:/pb_L2/genblk1.L2/prec \
    {sim:/pb_L2/genblk1.L2/\a[0] } \
    {sim:/pb_L2/genblk1.L2/\w[0] } \
    sim:/pb_L2/genblk1.L2/z 
    add wave -position insertpoint  \
    sim:/pb_L2/accum
    if {$DESIGN_NAME eq "bit_serial"} {
        add wave /pb_L2/genblk2/assert__accumulation_temporal
    } else {
        add wave /pb_L2/genblk2/assert__accumulation_spatial
    }
}
#################### RUN ALL #####################

run -all

################### AUTO QUIT ####################

if {[info exists AUTO]} {
    quit -sim
    exit
}