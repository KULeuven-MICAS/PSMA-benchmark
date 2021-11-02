
set RTL_PATH    ../rtl

vlog $RTL_PATH/helper.sv \
     $RTL_PATH/macro_utils.sv \
     $RTL_PATH/mult_2b.sv \
     $RTL_PATH/L1_mult.sv \
     $RTL_PATH/L2_mult.sv \
     $RTL_PATH/L2_mac.sv \
     $RTL_PATH/top_L2_mac.sv \
     $RTL_PATH/tb_L2_mac.sv \
     -suppress 2583

vsim test_L2 -voptargs=+acc
add wave -position insertpoint sim:/test_L2/L2/*
add wave -position insertpoint  \
sim:/test_L2/accum
add wave /test_L2/genblk1.assert__accumulation_spatial
add wave -position insertpoint  \
sim:/test_L2/L2/mac/L2/out
add wave -position insertpoint  \
{sim:/test_L2/L2/mac/L2/L1_mult_x[0]/L1_mult_y[0]/L1/out}
add wave -position insertpoint  \
{sim:/test_L2/L2/mac/L2/L1_mult_x[0]/L1_mult_y[1]/L1/out}
add wave -position insertpoint  \
{sim:/test_L2/L2/mac/L2/L1_mult_x[1]/L1_mult_y[0]/L1/out}
add wave -position insertpoint  \
{sim:/test_L2/L2/mac/L2/L1_mult_x[1]/L1_mult_y[1]/L1/out}
add wave -position insertpoint  \
sim:/test_L2/L2/mac/clk_en
add wave -position insertpoint  \
sim:/test_L2/L2/mac/clk_gate
run -all