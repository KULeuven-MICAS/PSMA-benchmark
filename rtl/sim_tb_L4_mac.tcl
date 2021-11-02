
set RTL_PATH   ../rtl
set HEADROOM "4"
set L4_MODE  "00"
set L3_MODE  "11"
set L2_MODE  "1111"
set BG       "11"
set DVAFS    "0"

if {$BG=="11"} {
  vlog $RTL_PATH/helper.sv \
    $RTL_PATH/macro_utils.sv \
    $RTL_PATH/mult_2b.sv \
    $RTL_PATH/counter.sv \
    $RTL_PATH/L1_mult.sv \
    $RTL_PATH/L2_mult.sv \
    $RTL_PATH/L3_mult.sv \
    $RTL_PATH/L4_mult.sv \
    $RTL_PATH/L4_mac.sv \
    $RTL_PATH/top_L4_mac.sv \
    $RTL_PATH/tb_L4_mac.sv \
    -suppress 2583 \
    -suppress 8315 \
    +define+BIT_SERIAL

  vsim test_L4 -voptargs=+acc \
  -G L4_MODE=2'b$L4_MODE \
  -G L3_MODE=2'b$L3_MODE \
  -G L2_MODE=4'b1111 \
  -G BG=2'b11 \
  -G DVAFS=1'b0 \
  -sv_seed 10

  add wave -position insertpoint  \
  sim:/test_L4/a_full \
  sim:/test_L4/w_full
  add wave -position insertpoint sim:/test_L4/top_L4_mac/*
  add wave -position insertpoint  \
  sim:/test_L4/mult_exp \
  sim:/test_L4/accum \
  sim:/test_L4/accum_exp \
  sim:/test_L4/accum_en
  # add wave /test_L4/genblk1.assert__accumulation_spatial
  add wave /test_L4/genblk1.assert__accumulation_temporal

  # L4_inputs
  add wave -position insertpoint  \
  sim:/test_L4/top_L4_mac/L4/a \
  sim:/test_L4/top_L4_mac/L4/w

  # L4_output
  add wave -position insertpoint  \
  sim:/test_L4/top_L4_mac/L4/L4_mult/out \
  sim:/test_L4/top_L4_mac/L4/z \
  sim:/test_L4/top_L4_mac/L4/z_tmp
} else {
  vlog $RTL_PATH/helper.sv \
    $RTL_PATH/macro_utils.sv \
    $RTL_PATH/mult_2b.sv \
    $RTL_PATH/L1_mult.sv \
    $RTL_PATH/L2_mult.sv \
    $RTL_PATH/L3_mult.sv \
    $RTL_PATH/L4_mult.sv \
    $RTL_PATH/L4_mac.sv \
    $RTL_PATH/top_L4_mac.sv \
    $RTL_PATH/tb_L4_mac.sv \
    -suppress 2583 

  vsim test_L4 -voptargs=+acc \
  -G L4_MODE=2'b$L4_MODE \
  -G L3_MODE=2'b$L3_MODE \
  -G L2_MODE=4'b$L2_MODE \
  -G BG=2'b$BG \
  -G DVAFS=1'b$DVAFS \
  -sv_seed 10

  add wave -position insertpoint  \
  sim:/test_L4/a_full \
  sim:/test_L4/w_full
  add wave -position insertpoint sim:/test_L4/top_L4_mac/*
  add wave -position insertpoint  \
  sim:/test_L4/mult_exp \
  sim:/test_L4/accum \
  sim:/test_L4/accum_exp \
  sim:/test_L4/accum_en
  # add wave /test_L4/genblk1.assert__accumulation_spatial
  add wave /test_L4/genblk1.assert__accumulation_spatial

  # L4_inputs
  add wave -position insertpoint  \
  sim:/test_L4/top_L4_mac/L4/a \
  sim:/test_L4/top_L4_mac/L4/w

  # L4_output
  add wave -position insertpoint  \
  sim:/test_L4/top_L4_mac/L4/L4_mult/out \
  sim:/test_L4/top_L4_mac/L4/z \
  sim:/test_L4/top_L4_mac/L4/z_tmp
  add wave -position insertpoint  \
  sim:/test_L4/out_88 \
  sim:/test_L4/out_84 \
  sim:/test_L4/out_82 \
  sim:/test_L4/out_44 \
  sim:/test_L4/out_22 
}
run -all