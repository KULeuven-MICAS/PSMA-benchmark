
set RTL_PATH    ../rtl

vlog $RTL_PATH/helper.sv \
     $RTL_PATH/macro_utils.sv \
     $RTL_PATH/mult_2b.sv \
     $RTL_PATH/L1_mult.sv \
     $RTL_PATH/L2_mult.sv \
     $RTL_PATH/L3_mult.sv \
     $RTL_PATH/L4_mult.sv \
     $RTL_PATH/top_L4_mult.sv \
     $RTL_PATH/tb_L4_mult.sv \
     -suppress 2583

vsim test_L4 -voptargs=+acc
add wave -position insertpoint  \
sim:/test_L4/a_full \
sim:/test_L4/w_full
add wave -position insertpoint sim:/test_L4/top_L4_mult/*
add wave -position insertpoint  \
sim:/test_L4/mult_exp
add wave /test_L4/genblk1.assert__accumulation_spatial

# L4_inputs
add wave -position insertpoint  \
sim:/test_L4/top_L4_mult/L4/a \
sim:/test_L4/top_L4_mult/L4/w

# L4_output
add wave -position insertpoint  \
sim:/test_L4/top_L4_mult/L4/out \
sim:/test_L4/top_L4_mult/L4/out_tmp
add wave -position insertpoint  \
sim:/test_L4/out_88 \
sim:/test_L4/out_84 \
sim:/test_L4/out_82 \
sim:/test_L4/out_44 \
sim:/test_L4/out_22 

# L2_00 
# add wave -position insertpoint  \
# {sim:/test_L4/top_L4_mult/L4/L2_mult_x[0]/L2_mult_y[0]/L2/out} \
# {sim:/test_L4/top_L4_mult/L4/L2_mult_x[0]/L2_mult_y[1]/L2/out} \
# {sim:/test_L4/top_L4_mult/L4/L2_mult_x[0]/L2_mult_y[2]/L2/out} \
# {sim:/test_L4/top_L4_mult/L4/L2_mult_x[0]/L2_mult_y[3]/L2/out} 

run -all