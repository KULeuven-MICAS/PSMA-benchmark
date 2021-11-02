// Copyright 2021 MICAS, KU LEUVEN
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); 
// you may not use this file except in compliance with the License, or, 
// at your option, the Apache License version 2.0. You may obtain a copy 
// of the License at https://solderpad.org/licenses/SHL-2.1/
// Unless required by applicable law or agreed to in writing, any work 
// distributed under the License is distributed on an “AS IS” BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
// See the License for the specific language governing permissions and 
// limitations under the License.

//-----------------------------------------------------
// Author:    Ehab Ibrahim
// File Name: L4_mac.sv
// Design:    L4_mac
// Function:  L4_mult with accumulation (output stationary)
//-----------------------------------------------------

import helper::*;

module L4_mac (clk, rst, prec, accum_en, a, w, z);
  
  //-------------Parameters------------------------------
  parameter             HEADROOM = 4; 
  parameter             L4_MODE  = 2'b00; 
  parameter             L3_MODE  = 2'b00;
  parameter             L2_MODE  = 4'b0000;   // Determines if in/out are shared for x/y dimensions
                                              // 0: input shared, 1: output shared
                                              // MODE[3:2] -> L2_mac, MODE[1:0] -> L1_mult
  parameter             BG     = 2'b00;       // Bitgroups (00: unroll in L2, 01: unroll in L3, 11: Unroll Temporally)
  parameter             DVAFS  = 1'b0;
  parameter             SIZE   = 4; 
  
  //-------------Local parameters------------------------
  localparam            L2_A_INPUTS   = helper::get_L2_A_inputs(DVAFS, L2_MODE);
  localparam            L2_W_INPUTS   = helper::get_L2_W_inputs(DVAFS, L2_MODE);
  localparam            L2_OUT_WIDTH  = helper::get_L2_out_width(DVAFS, BG, L2_MODE);   // Width of the multiplication
                                                                                        // See function definitions at helper package
  localparam            L3_A_INPUTS   = helper::get_ARR_A_inputs(L3_MODE);
  localparam            L3_W_INPUTS   = helper::get_ARR_W_inputs(L3_MODE);
  localparam            L3_OUT_WIDTH  = helper::get_L3_out_width(DVAFS, BG, {L3_MODE, L2_MODE});
  
  localparam            L4_A_INPUTS   = helper::get_ARR_A_inputs(L4_MODE);
  localparam            L4_W_INPUTS   = helper::get_ARR_W_inputs(L4_MODE);
  localparam            L4_OUT_WIDTH  = helper::get_L4_out_width(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, SIZE);
  localparam            L4_MAX_OUTS   = helper::get_L4_max_outs(DVAFS, {L4_MODE, L3_MODE, L2_MODE}, SIZE);
  
  localparam            Z_WIDTH       = L4_OUT_WIDTH + (L4_MAX_OUTS * HEADROOM); 
  localparam            H             = HEADROOM; 

  localparam            OUTS_88       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b0000); 
  localparam            OUTS_84       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b0010);
  localparam            OUTS_82       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b0011); 
  localparam            OUTS_44       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b1010);
  localparam            OUTS_22       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b1111); 
  localparam            WIDTH_88      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b0000); 
  localparam            WIDTH_84      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b0010); 
  localparam            WIDTH_82      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b0011); 
  localparam            WIDTH_44      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b1010); 
  localparam            WIDTH_22      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_MODE}, 4'b1111); 

  //-------------Inputs----------------------------------
  input                 clk, rst, accum_en; 
  input    [7:0]        a [SIZE][L4_A_INPUTS][4][L3_A_INPUTS][L2_A_INPUTS];   
  input    [7:0]        w [SIZE][L4_W_INPUTS][4][L3_W_INPUTS][L2_W_INPUTS];   
  input    [3:0]        prec;         // 9 cases of precision (activation * weight)
                                      // prec[3:2]: Activation precision, prec[1:0]: Weight precision
                                      // 00: 8b, 10: 4b, 11: 2b
  
  //-------------Outputs---------------------------------
  output reg  [Z_WIDTH-1:0]   z;   
  logic       [Z_WIDTH-1:0]   z_tmp; 
  
  //-------------Internal Signals------------------------
  logic    [L4_OUT_WIDTH-1: 0]  mult;
  
  //-------------Bit-Serial Signals----------------------
  `ifdef BIT_SERIAL
  logic    [3:0]    cnt_z, cnt_w; 
  logic             clk_w_strb, clk_z_strb; 

  counter count_w (
    .clk   (clk),
    .rst   (rst),
    .count (cnt_w),
    .out   (clk_w_strb)
  );
  counter count_z (
    .clk   (clk),
    .rst   (rst),
    .count (cnt_z),
    .out   (clk_z_strb)
  );

  always_comb begin
    unique case(prec)
      4'b0000: begin
        cnt_w = 4'b0011;
        cnt_z = 4'b1111; 
      end
      4'b0010: begin
        cnt_w = 4'b0001;
        cnt_z = 4'b0111; 
      end
      4'b0011: begin
        cnt_w = 4'b0000;
        cnt_z = 4'b0011; 
      end
      4'b1010: begin
        cnt_w = 4'b0001;
        cnt_z = 4'b0011; 
      end
      4'b1111: begin
        cnt_w = 4'b0000;
        cnt_z = 4'b0000; 
      end
      default: begin
        cnt_w = 4'b0011;
        cnt_z = 4'b1111; 
      end
    endcase
  end
  `endif

  //-------------Datapath--------------------------------
  `ifdef BIT_SERIAL
  always_ff @(posedge clk) begin
    if(rst)                 z<='0; 
    else if (clk_z_strb)    z<=z_tmp; 
  end
  `else
  always_ff @(posedge clk) begin
    if(rst) z<='0; 
    else    z<=z_tmp; 
  end
  `endif
  
  
  //-------------UUT Instantiation--------------
  L4_mult #(
    .L4_MODE    (L4_MODE),
    .L3_MODE    (L3_MODE), 
    .L2_MODE    (L2_MODE), 
    .BG         (BG), 
    .DVAFS      (DVAFS), 
    .SIZE       (SIZE)
  ) L4_mult (
    // Inputs 
    .prec       (prec), 
    .a          (a), 
    .w          (w), 
    // Bit-Serial Signals 
    `ifdef BIT_SERIAL
    .clk        (clk), 
    .rst        (rst), 
    .clk_w_strb (clk_w_strb), 
    .clk_z_strb (clk_z_strb), 
    `endif
    // Outputs
    .out        (mult)
  );
  
  generate
    always_comb begin
      unique case(prec)
        4'b0000: begin
          if(accum_en) for(int x=0; x<OUTS_88; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_88)+:(Z_WIDTH/OUTS_88)]  = mult[((L4_OUT_WIDTH*x)/OUTS_88)+:WIDTH_88] + z[((Z_WIDTH*x)/OUTS_88)+:WIDTH_88+H]; 
          end
          else for(int x=0; x<OUTS_88; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_88)+:(Z_WIDTH/OUTS_88)]  = mult[((L4_OUT_WIDTH*x)/OUTS_88)+:WIDTH_88]; 
          end
        end
        4'b0010: begin
          if (accum_en) for(int x=0; x<OUTS_84; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_84)+:(Z_WIDTH/OUTS_84)]  = mult[((L4_OUT_WIDTH*x)/OUTS_84)+:WIDTH_84] + z[((Z_WIDTH*x)/OUTS_84)+:WIDTH_84+H]; 
          end
          else for(int x=0; x<OUTS_84; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_84)+:(Z_WIDTH/OUTS_84)]  = mult[((L4_OUT_WIDTH*x)/OUTS_84)+:WIDTH_84]; 
          end
        end
        4'b0011: begin
          if(accum_en) for(int x=0; x<OUTS_82; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_82)+:(Z_WIDTH/OUTS_82)]  = mult[((L4_OUT_WIDTH*x)/OUTS_82)+:WIDTH_82] + z[((Z_WIDTH*x)/OUTS_82)+:WIDTH_82+H]; 
          end
          else for(int x=0; x<OUTS_82; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_82)+:(Z_WIDTH/OUTS_82)]  = mult[((L4_OUT_WIDTH*x)/OUTS_82)+:WIDTH_82]; 
          end
        end
        4'b1010: begin
          if(accum_en) for(int x=0; x<OUTS_44; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_44)+:(Z_WIDTH/OUTS_44)]  = mult[((L4_OUT_WIDTH*x)/OUTS_44)+:WIDTH_44] + z[((Z_WIDTH*x)/OUTS_44)+:WIDTH_44+H]; 
          end
          else for(int x=0; x<OUTS_44; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_44)+:(Z_WIDTH/OUTS_44)]  = mult[((L4_OUT_WIDTH*x)/OUTS_44)+:WIDTH_44]; 
          end
        end
        4'b1111: begin
          if(accum_en) for(int x=0; x<OUTS_22; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_22)+:(Z_WIDTH/OUTS_22)]  = mult[((L4_OUT_WIDTH*x)/OUTS_22)+:WIDTH_22] + z[((Z_WIDTH*x)/OUTS_22)+:WIDTH_22+H]; 
          end
          else for(int x=0; x<OUTS_22; x++) begin
            z_tmp[((Z_WIDTH*x)/OUTS_22)+:(Z_WIDTH/OUTS_22)]  = mult[((L4_OUT_WIDTH*x)/OUTS_22)+:WIDTH_22]; 
          end
        end
      endcase
    end
  endgenerate 
  
endmodule