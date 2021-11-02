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
// File Name: L2_mac.sv
// Design:    L2_mac
// Function:  Top module for L2_mult which has accumulates
//            and stores the output in a register
//            Supports 8x8, 8x4, 8x2, 4x4, 2x2 precisions
//            Can be SA, ST, or hybrid SA/ST
//-----------------------------------------------------

`include "macro_utils.sv"
import helper::*;

module L2_mac (clk, rst, prec, a, w, z);
  
  //-------------Parameters------------------------------
  parameter             HEADROOM  = 4;
  parameter             MODE      = 4'b0000;   // Determines if in/out are shared for x/y dimensions
                                               // 0: input shared, 1: output shared
                                               // MODE[3:2] -> L2_mac, MODE[1:0] -> L1_mult
  parameter             BG        = 2'b00;     // Bitgroups (00: unroll in MAC, 01: spatial unroll array, 11: temporal unroll)
  parameter             DVAFS     = 1'b0;
  
  //-------------Local parameters------------------------
  localparam            HEADROOM_HELP = BG[1] ? HEADROOM-4 : HEADROOM; 
  localparam            HELP_MODE     = (BG[1]) ? 4'b1111 : MODE;                           // If Temporal: Choose mode as 4'b1111
  localparam            L2_A_INPUTS   = helper::get_L2_A_inputs(DVAFS, HELP_MODE);          // No. of A and W inputs is 1 if SA, 
  localparam            L2_W_INPUTS   = helper::get_L2_W_inputs(DVAFS, HELP_MODE);          // 4 if ST, 2 if SA/ST
  localparam            MAX_OUTPUTS   = helper::get_L2_max_out(DVAFS, HELP_MODE);           // Max. number of outputs in each MODE
  localparam            MULT_WIDTH    = helper::get_L2_out_width(DVAFS, BG, HELP_MODE);  // Width of the 8x8 multiplication (without accumulation)
                                                    // See function definitions at helper package
                                                    
  // localparam            Z_WIDTH   = (BG[1]) ? MULT_WIDTH + 12 : MULT_WIDTH + (MAX_OUTPUTS * HEADROOM);
  localparam            Z_WIDTH   = MULT_WIDTH + (MAX_OUTPUTS * HEADROOM_HELP);
  
  //-------------For clock gating---------
  localparam            M       = Z_WIDTH / 2;    // Mid-Point of z 
  localparam            Q       = Z_WIDTH / 4;    // Quarter-Point of z 
  localparam            T       = 3*Z_WIDTH / 4;  // Three-Quarters-Point of z 
  localparam            H       = HEADROOM_HELP;  // Shorthand for headroom
  localparam            W       = MULT_WIDTH;     // Shorthand for 8x8 multiplication width
  
  //-------------Inputs----------------------------------
  input               clk, rst; 
  input    [7:0]      a [L2_A_INPUTS];   
  input    [7:0]      w [L2_W_INPUTS];   
  input    [3:0]      prec;   // 5 cases of precision (activation * weight)
                              // prec[3:2]: Activation precision, prec[1:0]: Weight precision
                              // 00: 8b, 10: 4b, 11: 2b
  
  //-------------Outputs---------------------------------
  output reg [Z_WIDTH-1:0]    z;
  logic      [Z_WIDTH-1:0]    z_tmp;
  
  
  //-------------Internal Signals------------------------
  logic    [MULT_WIDTH-1:0]   mult;
  logic    [Z_WIDTH-1:0]      clk_en, clk_gate;       // Clock gate for each bit of output - manipulate clk_en at each mode!

  //-------------Bit-Serial Signals----------------------
  logic    [MULT_WIDTH-2+6-11:0]  a_shift, a_shift_tmp, clk_en_a, clk_gate_a; 
  logic    [MULT_WIDTH-2-2-11:0]  a_shift_ctrl;        // Upper level (8) -2

  logic    [MULT_WIDTH-2+12-11:0] w_shift_tmp, z_op; 
  logic    [MULT_WIDTH-2+12-11:2] w_shift, clk_en_w, clk_gate_w; 
  logic    [MULT_WIDTH-2+4-11:0]  w_shift_ctrl;        // Upper level (14) -2

  logic    [Z_WIDTH-1:0]       clk_en_z, clk_gate_z;     // Clock gate for each bit of output - manipulate clk_en at each mode!
  logic                        mode_88, mode_84, mode_82, mode_44, mode_22;

  logic    [3:0]               cnt_z, cnt_w; 
  logic                        clk_z_shift, clk_w_shift, clk_z_strb, clk_w_strb; 

  
  
  //-------------Datapath--------------------------------
  
  //-------------UUT Instantiation--------------
  L2_mult #(
    .MODE   (MODE),
    .BG     (BG), 
    .DVAFS  (DVAFS)
  ) L2 (
    .prec   (prec), 
    .a      (a),
    .w      (w), 
    `ifdef BIT_SERIAL
    .clk    (clk), 
    .rst    (rst), 
    .clk_w_strb (clk_w_strb), 
    .clk_z_strb (clk_z_strb), 
    `endif
    .out    (mult)
  );

  always_comb begin
    unique case (prec)
      4'b0000: {mode_88,mode_84,mode_82,mode_44,mode_22} = 5'b10000;
      4'b0010: {mode_88,mode_84,mode_82,mode_44,mode_22} = 5'b01000;
      4'b0011: {mode_88,mode_84,mode_82,mode_44,mode_22} = 5'b00100;
      4'b1010: {mode_88,mode_84,mode_82,mode_44,mode_22} = 5'b00010;
      4'b1111: {mode_88,mode_84,mode_82,mode_44,mode_22} = 5'b00001;
    endcase
  end

  generate
    if(BG[1]) begin: COUNTERS
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
        unique case(1'b1)
          mode_88: begin
            cnt_w = 4'b0011;
            cnt_z = 4'b1111; 
          end
          mode_84: begin
            cnt_w = 4'b0001;
            cnt_z = 4'b0111; 
          end
          mode_82: begin
            cnt_w = 4'b0000;
            cnt_z = 4'b0011; 
          end
          mode_44: begin
            cnt_w = 4'b0001;
            cnt_z = 4'b0011; 
          end
          mode_22: begin
            cnt_w = 4'b0000;
            cnt_z = 4'b0000; 
          end
        endcase
      end
    end
  endgenerate
  
  //-------------Accumulation and Clock Enable-------------
  genvar i;
  generate
    case(DVAFS)
      1'b0: begin: DVAFS_OFF
        case(BG)
          2'b00: begin: BG_MAC
            
            //-------------Clock Gating-------------
            // Only performed if BG is unrolled inside the MAC
            
            always_comb begin
              clk_gate  = {Z_WIDTH{clk}} & clk_en;
            end
            
            for(i=0; i<Z_WIDTH; i++) begin: Z_CLK_GATING
              always_ff @(posedge clk_gate[i]) begin
                if (rst) z[i] <= 0;
                else     z[i] <= z_tmp[i];
              end
            end
            
            case({MODE[3], MODE[2]})
              2'b00: begin: L2_IN_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // MULT_WIDTH = W = 64-bits @(2x2)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case(1'b1) 
                          mode_88: begin
                            z_tmp[0+:16+H]    = mult[0+:16] + z[0+:16+H];
                            clk_en = {{Z_WIDTH-(16+H){1'b0}}, {16+H{1'b1}}};
                          end
                          mode_84: begin
                            `accum_out_2_utils(z_tmp, 12+H);
                            clk_en = {{M-(12+H){1'b0}}, {12+H{1'b1}}, {M-(12+H){1'b0}}, {12+H{1'b1}}};
                          end
                          mode_82: begin
                            `accum_out_4_utils(z_tmp, 10+H);
                            clk_en = {{Q-(10+H){1'b0}}, {10+H{1'b1}}, {Q-(10+H){1'b0}}, {10+H{1'b1}}, {Q-(10+H){1'b0}}, {10+H{1'b1}}, {Q-(10+H){1'b0}}, {10+H{1'b1}}};
                          end
                          mode_44: begin
                            `accum_out_4_utils(z_tmp, 8+H);
                            clk_en = {{Q-(8+H){1'b0}}, {8+H{1'b1}}, {Q-(8+H){1'b0}}, {8+H{1'b1}}, {Q-(8+H){1'b0}}, {8+H{1'b1}}, {Q-(8+H){1'b0}}, {8+H{1'b1}}};
                          end
                          mode_22: begin
                            `accum_out_16_utils(z_tmp, 4+H);
                            clk_en = '1;
                          end
                        endcase
                      end
                    end
                  end
                  2'b10: begin: L1_OUT_IN  // MULT_WIDTH = W = 40-bits @(2x2)
                    always_comb begin
                    if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp[0+:16+H]    = mult[0+:16] + z[0+:16+H];
                            clk_en = {{Z_WIDTH-(16+H){1'b0}}, {16+H{1'b1}}};
                          end
                          mode_84: begin
                            `accum_out_2_utils(z_tmp, 12+H);
                            clk_en = {{M-(12+H){1'b0}}, {12+H{1'b1}}, {M-(12+H){1'b0}}, {12+H{1'b1}}};
                          end
                          mode_82: begin
                            `accum_out_2_utils(z_tmp, 11+H);
                            clk_en = {{M-(11+H){1'b0}}, {11+H{1'b1}}, {M-(11+H){1'b0}}, {11+H{1'b1}}};
                          end
                          mode_44: begin
                            `accum_out_4_utils(z_tmp, 8+H)
                            clk_en = {{Q-(8+H){1'b0}}, {8+H{1'b1}}, {Q-(8+H){1'b0}}, {8+H{1'b1}}, {Q-(8+H){1'b0}}, {8+H{1'b1}}, {Q-(8+H){1'b0}}, {8+H{1'b1}}};
                          end
                          mode_22: begin
                            `accum_out_8_utils(z_tmp, 5+H); 
                            clk_en = '1;
                          end
                        endcase
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // MULT_WIDTH = W = 32-bits @(4x4)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp[0+:16+H]    = mult[0+:16] + z[0+:16+H];
                            clk_en = {{Z_WIDTH-(16+H){1'b0}}, {16+H{1'b1}}};
                          end
                          mode_84: begin
                            `accum_out_2_utils(z_tmp, 12+H);
                            clk_en = {{M-(12+H){1'b0}}, {12+H{1'b1}}, {M-(12+H){1'b0}}, {12+H{1'b1}}};
                          end
                          mode_82: begin
                            `accum_out_2_utils(z_tmp, 11+H);
                            clk_en = {{M-(11+H){1'b0}}, {11+H{1'b1}}, {M-(11+H){1'b0}}, {11+H{1'b1}}};
                          end
                          mode_44: begin
                            `accum_out_4_utils(z_tmp, 8+H)
                            clk_en = '1;
                          end
                          mode_22: begin
                            `accum_out_4_utils(z_tmp, 6+H)
                            clk_en = {{Q-(6+H){1'b0}}, {6+H{1'b1}}, {Q-(6+H){1'b0}}, {6+H{1'b1}}, {Q-(6+H){1'b0}}, {6+H{1'b1}}, {Q-(6+H){1'b0}}, {6+H{1'b1}}};
                          end
                        endcase
                      end
                    end
                  end
                endcase
              end
              2'b10: begin: L2_OUT_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN   // MULT_WIDTH = W = 40-bits @(2x2)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp[0+:16+H]    = mult[0+:16] + z[0+:16+H];
                            clk_en = {{Z_WIDTH-(16+H){1'b0}}, {16+H{1'b1}}};
                          end
                          mode_84: begin
                            z_tmp[0+:13+H]    = mult[0+:13] + z[0+:13+H];
                            clk_en = {{Z_WIDTH-(13+H){1'b0}}, {13+H{1'b1}}};
                          end
                          mode_82: begin
                            `accum_out_2_utils(z_tmp, 11+H);
                            clk_en = {{M-(11+H){1'b0}}, {11+H{1'b1}}, {M-(11+H){1'b0}}, {11+H{1'b1}}};
                          end
                          mode_44: begin
                            `accum_out_2_utils(z_tmp, 9+H); 
                            clk_en = {{M-(9+H){1'b0}}, {9+H{1'b1}}, {M-(9+H){1'b0}}, {9+H{1'b1}}};
                          end
                          mode_22: begin
                            `accum_out_8_utils(z_tmp, 5+H); 
                            clk_en = '1;
                          end
                        endcase
                      end
                    end
                  end
                  2'b10: begin: L1_OUT_IN   // MULT_WIDTH = W = 24-bits @(2x2)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp[0+:16+H]    = mult[0+:16] + z[0+:16+H];
                            clk_en = {{Z_WIDTH-(16+H){1'b0}}, {16+H{1'b1}}};
                          end
                          mode_84: begin
                            z_tmp[0+:13+H]    = mult[0+:13] + z[0+:13+H];
                            clk_en = {{Z_WIDTH-(13+H){1'b0}}, {13+H{1'b1}}};
                          end
                          mode_82: begin
                            z_tmp[0+:12+H]    = mult[0+:12] + z[0+:12+H];
                            clk_en = {{Z_WIDTH-(12+H){1'b0}}, {12+H{1'b1}}};
                          end
                          mode_44: begin
                            `accum_out_2_utils(z_tmp, 9+H); 
                            clk_en = {{M-(9+H){1'b0}}, {9+H{1'b1}}, {M-(9+H){1'b0}}, {9+H{1'b1}}};
                          end
                          mode_22: begin
                            `accum_out_4_utils(z_tmp, 6+H)
                            clk_en = '1;
                          end
                        endcase
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT   // MULT_WIDTH = W = 18-bits @(4x4)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp[0+:16+H]    = mult[0+:16] + z[0+:16+H];
                            clk_en = {{Z_WIDTH-(16+H){1'b0}}, {16+H{1'b1}}};
                          end
                          mode_84: begin
                            z_tmp[0+:13+H]    = mult[0+:13] + z[0+:13+H];
                            clk_en = {{Z_WIDTH-(13+H){1'b0}}, {13+H{1'b1}}};
                          end
                          mode_82: begin
                            z_tmp[0+:12+H]    = mult[0+:12] + z[0+:12+H];
                            clk_en = {{Z_WIDTH-(12+H){1'b0}}, {12+H{1'b1}}};
                          end
                          mode_44: begin
                            `accum_out_2_utils(z_tmp, 9+H); 
                            clk_en = '1;
                          end
                          mode_22: begin
                            `accum_out_2_utils(z_tmp, 7+H); 
                            clk_en = {{M-(7+H){1'b0}}, {7+H{1'b1}}, {M-(7+H){1'b0}}, {7+H{1'b1}}};
                          end
                        endcase
                      end
                    end
                  end
                endcase
              end
              2'b11: begin: L2_OUT_OUT
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN   // MULT_WIDTH = W = 24-bits @(2x2)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp[0+:16+H]    = mult[0+:16] + z[0+:16+H];
                            clk_en = {{Z_WIDTH-(16+H){1'b0}}, {16+H{1'b1}}};
                          end
                          mode_84: begin
                            z_tmp[0+:13+H]    = mult[0+:13] + z[0+:13+H];
                            clk_en = {{Z_WIDTH-(13+H){1'b0}}, {13+H{1'b1}}};
                          end
                          mode_82: begin
                            `accum_out_2_utils(z_tmp, 11+H);
                            clk_en = {{M-(11+H){1'b0}}, {11+H{1'b1}}, {M-(11+H){1'b0}}, {11+H{1'b1}}};
                          end
                          mode_44: begin
                            z_tmp[0+:10+H]    = mult[0+:10] + z[0+:10+H];
                            clk_en = {{Z_WIDTH-(10+H){1'b0}}, {10+H{1'b1}}};
                          end
                          mode_22: begin
                            `accum_out_4_utils(z_tmp, 6+H)
                            clk_en = '1;
                          end
                        endcase
                      end
                    end
                  end
                  2'b10: begin: L1_OUT_IN   // MULT_WIDTH = W = 16-bits @(8x8)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp = $unsigned(z) + $unsigned(mult);
                            clk_en = '1;
                          end
                          mode_84: begin
                            z_tmp = $unsigned(z[12+H:0]) + $unsigned(mult[12:0]);
                            clk_en = {{Z_WIDTH-(13+H){1'b0}}, {13+H{1'b1}}};
                          end
                          mode_82: begin
                            z_tmp = $unsigned(z[11+H:0]) + $unsigned(mult[11:0]);
                            clk_en = {{Z_WIDTH-(12+H){1'b0}}, {12+H{1'b1}}};
                          end
                          mode_44: begin
                            z_tmp = $unsigned(z[9+H:0])  + $unsigned(mult[9:0]);
                            clk_en = {{Z_WIDTH-(10+H){1'b0}}, {10+H{1'b1}}};
                          end
                          mode_22: begin
                            `accum_out_2_utils(z_tmp, 7+H); 
                            clk_en = {{M-(7+H){1'b0}}, {7+H{1'b1}}, {M-(7+H){1'b0}}, {7+H{1'b1}}};
                          end
                        endcase
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT   // MULT_WIDTH = W = 16-bits @(8x8)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp = $unsigned(z) + $unsigned(mult);
                            clk_en = '1;
                          end
                          mode_84: begin
                            z_tmp = $unsigned(z[12+H:0]) + $unsigned(mult[12:0]);
                            clk_en = {{Z_WIDTH-(13+H){1'b0}}, {13+H{1'b1}}};
                          end
                          mode_82: begin
                            z_tmp = $unsigned(z[11+H:0]) + $unsigned(mult[11:0]);
                            clk_en = {{Z_WIDTH-(12+H){1'b0}}, {12+H{1'b1}}};
                          end
                          mode_44: begin
                            z_tmp = $unsigned(z[9+H:0])  + $unsigned(mult[9:0]);
                            clk_en = {{Z_WIDTH-(10+H){1'b0}}, {10+H{1'b1}}};
                          end
                          mode_22: begin
                            z_tmp = $unsigned(z[7+H:0])  + $unsigned(mult[7:0]);
                            clk_en = {{Z_WIDTH-(8+H){1'b0}}, {8+H{1'b1}}};
                          end
                        endcase
                      end
                    end
                  end
                endcase
              end
            endcase
          end
          2'b01: begin: BG_ARR
          
            // No clock gating if BG is unrolled out of MAC - no need for clk_gate & clk_en
            always_ff @(posedge clk) begin
              if (rst) z <= '0;
              else     z <= z_tmp;
            end
            
            case({MODE[3], MODE[2]})
              2'b00: begin: L2_IN_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_16_utils(z_tmp, 4+H);
                      end
                    end
                  end
                  2'b10: begin: L1_OUT_IN
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_8_utils(z_tmp, 5+H); 
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        z_tmp[1 *(6+H)-1 -: 6+H] = mult[(1 *6)-1 -: 6] + z[1 *(6+H)-1 -: 6+H];
                        z_tmp[2 *(6+H)-1 -: 6+H] = mult[(2 *6)-1 -: 6] + z[2 *(6+H)-1 -: 6+H];
                        z_tmp[3 *(6+H)-1 -: 6+H] = mult[(3 *6)-1 -: 6] + z[3 *(6+H)-1 -: 6+H];
                        z_tmp[4 *(6+H)-1 -: 6+H] = mult[(4 *6)-1 -: 6] + z[4 *(6+H)-1 -: 6+H];
                      end
                    end
                  end
                endcase
              end
              2'b10: begin: L2_OUT_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_8_utils(z_tmp, 5+H); 
                      end
                    end
                  end
                  2'b10: begin: L1_OUT_IN
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_4_utils(z_tmp, Q);
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_2_utils(z_tmp, M);
                      end
                    end
                  end
                endcase
              end
              2'b11: begin: L2_OUT_OUT
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_4_utils(z_tmp, Q);
                      end
                    end
                  end
                  2'b10: begin: L1_OUT_IN
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_2_utils(z_tmp, M);
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT
                    assign z_tmp = (rst) ? '0 : $unsigned(z) + $unsigned(mult);
                  end
                endcase
              end
            endcase
          end

          2'b11: begin: BG_TEMP
            for(genvar i=0; i<Z_WIDTH; i++) begin
              always_ff @(posedge clk) begin
                if (rst)            z[i] <= '0; 
                else if(clk_z_strb) z[i] <= z_tmp[i]; 
              end
            end
            always_comb begin
              z_tmp = $unsigned(mult) + $unsigned(z);
            end
          end
        endcase
      end
      
      
      
      
      
      1'b1: begin: DVAFS_ON
        case(BG)
          2'b00: begin: BG_MAC
            
            //-------------Clock Gating-------------
            // Only performed if BG is unrolled inside the MAC
            
            always_comb begin
              clk_gate  = {Z_WIDTH{clk}} & clk_en;
            end
            
            for(i=0; i<Z_WIDTH; i++) begin: Z_CLK_GATING
              always_ff @(posedge clk_gate[i]) begin
                if (rst) z[i] <= 0;
                else   z[i] <= z_tmp[i];
              end
            end
            
            case({MODE[3], MODE[2]})
              2'b00: begin: L2_IN_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // MULT_WIDTH = W = 64-bits @(2x2)
                    always_comb begin
                      if(rst) begin 
                        z_tmp  = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case(1'b1) 
                          mode_88: begin
                            z_tmp[0+:16+H]  = mult + z[0+:16+H];
                            clk_en = {{Z_WIDTH-(16+H){1'b0}}, {16+H{1'b1}}};
                          end
                          mode_44: begin
                            // z_tmp[0+:8+H]      = mult[0+:(W/2)]     + z[0+:8+H];
                            // z_tmp[M+:8+H]      = mult[(W/2)+:(W/2)]   + z[M+:8+H];
                            `accum_out_2_utils(z_tmp, 8+H);
                            clk_en = {{M-(8+H){1'b0}}, {8+H{1'b1}}, {M-(8+H){1'b0}}, {8+H{1'b1}}};
                          end
                          mode_22: begin
                            `accum_out_4_utils(z_tmp, Q);
                            clk_en = '1;
                          end
                        endcase
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // MULT_WIDTH = W = 32-bits @(4x4)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp[0+:16+H]  = mult + z[0+:16+H];
                            clk_en = {{Z_WIDTH-(16+H){1'b0}}, {16+H{1'b1}}};
                          end
                          mode_44: begin
                            `accum_out_2_utils(z_tmp, M);
                            clk_en = '1;
                          end
                          mode_22: begin
                            `accum_out_2_utils(z_tmp, 5+H);
                            clk_en = {{M-(5+H){1'b0}}, {5+H{1'b1}}, {M-(5+H){1'b0}}, {5+H{1'b1}}};
                          end
                        endcase
                      end
                    end
                  end
                endcase
              end
              2'b11: begin: L2_OUT_OUT
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN   // MULT_WIDTH = W = 24-bits @(2x2)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin  // 1x16b  //TODO: Look again here; if H>7, 2x2 will have highest bit-width
                            // z_tmp[0+:16+H]  = mult + z[0+:16+H];
                            z_tmp  = mult + z;
                            clk_en = '1;
                          end
                          mode_44: begin  // 1x9b
                            z_tmp[0+:9+H]    = mult[0+:9] + z[0+:9+H];
                            clk_en = {{Z_WIDTH-(9+H){1'b0}}, {9+H{1'b1}}};
                          end
                          mode_22: begin  // 2x5b
                            `accum_out_2_utils(z_tmp, 5+H);
                            clk_en = {{M-(5+H){1'b0}}, {5+H{1'b1}}, {M-(5+H){1'b0}}, {5+H{1'b1}}};
                          end
                        endcase
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT   // MULT_WIDTH = W = 16-bits @(8x8)
                    always_comb begin
                      if(rst) begin 
                        z_tmp = '0;
                        clk_en = '1;
                      end
                      else begin
                        unique case (1'b1) 
                          mode_88: begin
                            z_tmp  = mult + z;
                            clk_en = '1;
                          end
                          mode_44: begin
                            z_tmp[0+:9+H]    = mult[0+:9] + z[0+:9+H];
                            clk_en = {{Z_WIDTH-(9+H){1'b0}}, {9+H{1'b1}}};
                          end
                          mode_22: begin
                            z_tmp[0+:6+H]    = mult[0+:6] + z[0+:6+H];
                            clk_en = {{Z_WIDTH-(6+H){1'b0}}, {6+H{1'b1}}};
                          end
                        endcase
                      end
                    end
                  end
                endcase
              end
            endcase
          end
          2'b01: begin: BG_ARR
          
            // No clock gating if BG is unrolled out of MAC - no need for clk_gate & clk_en
            always_ff @(posedge clk) begin
              if (rst) z <= '0;
              else   z <= z_tmp;
            end
            
            case({MODE[3], MODE[2]})
              2'b00: begin: L2_IN_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_4_utils(z_tmp, Q);
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_2_utils(z_tmp, 5+H);
                      end
                    end
                  end
                endcase
              end
              2'b11: begin: L2_OUT_OUT
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN
                    always_comb begin
                      if(rst) z_tmp = '0;
                      else begin
                        `accum_out_2_utils(z_tmp, 5+H);
                      end
                    end
                  end
                  2'b11: begin: L1_OUT_OUT
                    assign z_tmp = (rst) ? '0 : $unsigned(z) + $unsigned(mult);
                  end
                endcase
              end
            endcase
          end

          2'b11: begin: BG_TEMP

          end
        endcase
      end
    endcase
  endgenerate
  
endmodule