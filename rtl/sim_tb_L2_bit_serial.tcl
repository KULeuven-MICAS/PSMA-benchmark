
set RTL_PATH    ../rtl

vlog $RTL_PATH/helper.sv \
    $RTL_PATH/macro_utils.sv \
    $RTL_PATH/mult_2b.sv \
    $RTL_PATH/L1_mult.sv \
    $RTL_PATH/L2_mult.sv \
    $RTL_PATH/L2_mac.sv \
    $RTL_PATH/top_L2_mac.sv \
    $RTL_PATH/tb_L2_mac.sv \
    +define+BIT_SERIAL \
    -suppress 2583

vsim test_L2 -t ns \
    -G BG=2'b11 \
    -voptargs=+acc
add wave -position insertpoint  \
sim:/test_L2/a_full \
sim:/test_L2/w_full
add wave -position insertpoint sim:/test_L2/L2/*
add wave -position insertpoint  \
sim:/test_L2/accum
add wave /test_L2/genblk1/assert__accumulation_temporal
add wave -position insertpoint  \
sim:/test_L2/L2/mac/L2/out_tmp
add wave -position insertpoint  \
sim:/test_L2/L2/mac/cnt_w \
sim:/test_L2/L2/mac/cnt_z \
sim:/test_L2/mult_exp

add wave -position insertpoint  \
sim:/test_L2/L2/mac/L2/a_shift_ctrl \
sim:/test_L2/L2/mac/L2/a_shift_tmp \
sim:/test_L2/L2/mac/L2/a_shift \
sim:/test_L2/L2/mac/L2/w_shift_ctrl \
sim:/test_L2/L2/mac/L2/w_shift_tmp \
sim:/test_L2/L2/mac/L2/w_shift \
sim:/test_L2/L2/mac/L2/clk_w_strb \
sim:/test_L2/L2/mac/L2/clk_z_strb

# add wave -position insertpoint  \
# sim:/test_L2/L2/mac/clk_en_z \
# sim:/test_L2/L2/mac/clk_gate_z \
# sim:/test_L2/L2/mac/clk_en_a \
# sim:/test_L2/L2/mac/clk_gate_a \
# sim:/test_L2/L2/mac/clk_en_w \
# sim:/test_L2/L2/mac/clk_gate_w
run -all