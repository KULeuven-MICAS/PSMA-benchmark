
if {[info exists AUTO]} {
    # Auto-mode defines its own parameters
    puts "\033\[41;97;1mAutomatic processing\033\[0m"

} else {
    # Set the LIB_V file here
    # set LIB_V           ../lib/..../.v
    set CLK_PERIOD      5.00
    set TEST            0 
    set PRECISION       1111
    set HEADROOM        4 
    set BG              01
    set L4_MODE         11 
    set L3_MODE         11
    set L2_MODE         1111
    set L2_N            [string range $L2_MODE 0 1]
    set DVAFS           0 
    set REP             128 
    set RST             1
    set VCD_FILE        ./dump_${PRECISION}_clk${CLK_PERIOD}.vcd
    if {$BG==00} {
        set BGN         L2
    } elseif {$BG==01} {
        set BGN         L3
    } else {
        set BGN         BS
    }
    # Set the export path here
    set EXPORT_PATH     ../results/BG_${BGN}_L4_${L4_MODE}_L3_${L3_MODE}_L2_${L2_N}_DVAFS_${DVAFS}/clk:${CLK_PERIOD}-${CLK_PERIOD}-${CLK_PERIOD}
    set V_FILE          $EXPORT_PATH/post.v
    set SDF_FILE        $EXPORT_PATH/post.sdf
    set RTL_PATH        ../rtl
    set PB_FILE         $RTL_PATH/pb_L4_mac.sv
    set HELPER          $RTL_PATH/helper.sv
    puts "\033\[41;97;1mManual processing of $V_FILE\033\[0m"
}
    
vlog -quiet $LIB_V
if {$BG==11} {
    vlog -quiet $HELPER $V_FILE $PB_FILE +define+BIT_SERIAL
} else {
    vlog -quiet $HELPER $V_FILE $PB_FILE
}

if {[info exists AUTO]} {

    vsim pb_L4 -t ps \
    -G TEST=$TEST \
    -G PRCSN=4'b${PRECISION} \
    -G CLK_PRD=${CLK_PERIOD}ns \
    -G HEADROOM=$HEADROOM \
    -G L4_MODE=2'b$L4_MODE \
    -G L3_MODE=2'b$L3_MODE \
    -G L2_MODE=4'b$L2_MODE \
    -G BG=2'b$BG \
    -G DVAFS=1'b$DVAFS \
    -G RST=$RST \
    -G REP=$REP \
    -G VCD_FILE=$VCD_FILE \
    -sdfmax genblk1.genblk1.top_L4_mac=$SDF_FILE \
    -sv_seed 10 +nowarn3819

} else {
    vsim pb_L4 -t ps \
    -G TEST=$TEST \
    -G PRCSN=4'b${PRECISION} \
    -G CLK_PRD=${CLK_PERIOD}ns \
    -G HEADROOM=$HEADROOM \
    -G L4_MODE=2'b$L4_MODE \
    -G L3_MODE=2'b$L3_MODE \
    -G L2_MODE=4'b$L2_MODE \
    -G BG=2'b$BG \
    -G DVAFS=1'b$DVAFS \
    -G RST=$RST \
    -G REP=$REP \
    -G VCD_FILE=$VCD_FILE \
    -sdfmax genblk1.genblk1.top_L4_mac=$SDF_FILE -voptargs=+acc \
    -sv_seed 10 +nowarn3819
    
    add wave -position insertpoint  \
    sim:/pb_L4/genblk1.genblk1.top_L4_mac/clk \
    sim:/pb_L4/genblk1.genblk1.top_L4_mac/rst \
    sim:/pb_L4/genblk1.genblk1.top_L4_mac/prec \
    sim:/pb_L4/genblk1.genblk1.top_L4_mac/z 
    add wave -position insertpoint  \
    sim:/pb_L4/mult_exp \
    sim:/pb_L4/accum \
    sim:/pb_L4/accum_exp \
    sim:/pb_L4/accum_en
    
    if {$BG==11} {
        add wave /pb_L4/genblk2/assert__accumulation_temporal
    } else {
        add wave /pb_L4/genblk2/assert__accumulation_spatial
    }
    
} 
#################### RUN ALL #####################

run -all

################### AUTO QUIT ####################

if {[info exists AUTO]} {
    quit -sim
    exit
}