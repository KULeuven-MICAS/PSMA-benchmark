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
// File Name: L3_mult.sv
// Design:    L3_mult
// Function:  A 4x4 array of L2_mult 
//-----------------------------------------------------

import helper::*;

module L3_mult (prec, a, w, 
                `ifdef BIT_SERIAL 
                clk, rst, clk_w_strb, clk_z_strb, 
                `endif
                out);
  
  //-------------Parameters------------------------------
  parameter             L3_MODE  = 2'b00;
  parameter             L2_MODE  = 4'b0000;   // Determines if in/out are shared for x/y dimensions
                              // 0: input shared, 1: output shared
                              // MODE[3:2] -> L2_mac, MODE[1:0] -> L1_mult
  parameter             BG     = 2'b00;     // Bitgroups (00: unroll in L2, 01: unroll in L3, 11: Unroll Temporally)
  parameter             DVAFS  = 1'b0;
  
  //-------------Local parameters------------------------
  localparam            MODE          = {L3_MODE, L2_MODE}; 
  localparam            L2_A_INPUTS   = helper::get_L2_A_inputs(DVAFS, L2_MODE);
  localparam            L2_W_INPUTS   = helper::get_L2_W_inputs(DVAFS, L2_MODE);
  localparam            L2_OUT_WIDTH  = helper::get_L2_out_width(DVAFS, BG, L2_MODE);   // Width of the multiplication
                                                  // See function definitions at helper package
  localparam            L3_A_INPUTS   = helper::get_ARR_A_inputs(L3_MODE);
  localparam            L3_W_INPUTS   = helper::get_ARR_W_inputs(L3_MODE);
  localparam            L3_OUT_WIDTH  = helper::get_L3_out_width(DVAFS, BG, MODE);
  
  // L2_out Quarter, Mid, and Three-Quarter points 
  localparam            Q       = L2_OUT_WIDTH * 1/4;
  localparam            M       = L2_OUT_WIDTH * 2/4;
  localparam            T       = L2_OUT_WIDTH * 3/4;

  // L3_out divided to 16 points: Quarter = PQ4, Mid = PM4, Three-Quarter = PT4
  localparam            PQ1       = L3_OUT_WIDTH * 1/16;
  localparam            PQ2       = L3_OUT_WIDTH * 2/16;
  localparam            PQ3       = L3_OUT_WIDTH * 3/16;
  localparam            PQ4       = L3_OUT_WIDTH * 4/16;
  localparam            PM1       = L3_OUT_WIDTH * 5/16;
  localparam            PM2       = L3_OUT_WIDTH * 6/16;
  localparam            PM3       = L3_OUT_WIDTH * 7/16;
  localparam            PM4       = L3_OUT_WIDTH * 8/16;
  localparam            PT1       = L3_OUT_WIDTH * 9/16;
  localparam            PT2       = L3_OUT_WIDTH * 10/16;
  localparam            PT3       = L3_OUT_WIDTH * 11/16;
  localparam            PT4       = L3_OUT_WIDTH * 12/16;
  localparam            PZ1       = L3_OUT_WIDTH * 13/16;
  localparam            PZ2       = L3_OUT_WIDTH * 14/16;
  localparam            PZ3       = L3_OUT_WIDTH * 15/16;
  //-------------Inputs----------------------------------
  input    [7:0]        a [4][L3_A_INPUTS][L2_A_INPUTS];   
  input    [7:0]        w [4][L3_W_INPUTS][L2_W_INPUTS];   
  input    [3:0]        prec;         // 9 cases of precision (activation * weight)
                            // prec[3:2]: Activation precision, prec[1:0]: Weight precision
                            // 00: 8b, 10: 4b, 11: 2b
  
  //-------------Outputs---------------------------------
  output   [L3_OUT_WIDTH-1:0]   out;   
  logic    [L3_OUT_WIDTH-1:0]   out_tmp; 
  
  //-------------Internal Signals------------------------
  
  // L2_mult signals:
  logic    [7:0]                L2_a   [4][4][L2_A_INPUTS];
  logic    [7:0]                L2_w   [4][4][L2_W_INPUTS];
  logic    [L2_OUT_WIDTH-1:0]   L2_out [4][4];

  //-------------Bit-Serial Signals----------------------
  `ifdef BIT_SERIAL 
  input    clk, rst, clk_w_strb, clk_z_strb;
  `endif
  
  //-------------Datapath--------------------------------
  assign out = out_tmp; 

  //-------------UUT Instantiation--------------
  
  genvar L2_x, L2_y;
  generate
    // GENERATE 4x L1_mult modules
    for(L2_x=0; L2_x<4; L2_x++) begin: L2_mult_x
      for(L2_y=0; L2_y<4; L2_y++) begin: L2_mult_y
        // TODO: Consider adding L2_mac here in case BG is out of L3 AND L3_MODE is 00
        // In this case, also add Z_WIDTH parameter for L2 
        // if({BG, L3_MODE}==4'b0000 || {BG, L3_MODE}==4'b1100) begin
        // end
        L2_mult #(
          // Parameters
          .MODE   (L2_MODE),
          .BG     (BG[0]), 
          .DVAFS  (DVAFS)
        ) L2 (
          // Inputs
          .prec   (prec),
          .w    (L2_w[L2_x][L2_y]), 
          .a    (L2_a[L2_x][L2_y]),
          // Bit-Serial Signals 
          `ifdef BIT_SERIAL
          .clk        (clk), 
          .rst        (rst), 
          .clk_w_strb (clk_w_strb), 
          .clk_z_strb (clk_z_strb), 
          `endif
          // Outputs
          .out    (L2_out[L2_x][L2_y])
        );
      end
    end
  endgenerate
  
  generate
    case(DVAFS)
      1'b0: begin: DVAFS_OFF
        case(BG[0]^BG[1]) // If the same bits (00 or 11): No shifters in L3, else (01): Shifters in L3 
          1'b0: begin: BG_L2    // BG_00 OR BG_11: No shifters in L3 
            case(L3_MODE)
              2'b00: begin: L3_IN_IN
                // Always concatenate outputs from L2 in this case 
                // Always broadcast inputs, regardless of L2_mode
                // Don't need another case statement! 
                always_comb begin
                  // Each one of w[x][y] and a[x][y] are a collection of L2_inputs
                  // w[x][y] and a[x][y] are always broadcast on L3 level 
                  L2_w = '{'{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}};
                  
                  L2_a = '{'{a[0][0], a[0][0], a[0][0], a[0][0]}, 
                           '{a[1][0], a[1][0], a[1][0], a[1][0]}, 
                           '{a[2][0], a[2][0], a[2][0], a[2][0]}, 
                           '{a[3][0], a[3][0], a[3][0], a[3][0]}};

                  out_tmp = {L2_out[0][0], L2_out[0][1], L2_out[0][2], L2_out[0][3], 
                             L2_out[1][0], L2_out[1][1], L2_out[1][2], L2_out[1][3],
                             L2_out[2][0], L2_out[2][1], L2_out[2][2], L2_out[2][3],
                             L2_out[3][0], L2_out[3][1], L2_out[3][2], L2_out[3][3]};
                end
              end
              2'b10: begin: L3_OUT_IN
                // In this mode, different precisions affect the outputs
                // No shifters added here, just different adder logic 
                always_comb begin
                  L2_w = '{'{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}};
                  
                  L2_a = '{'{a[0][0], a[0][2], a[0][1], a[0][3]}, 
                           '{a[1][0], a[1][2], a[1][1], a[1][3]}, 
                           '{a[2][0], a[2][2], a[2][1], a[2][3]}, 
                           '{a[3][0], a[3][2], a[3][1], a[3][3]}};
                end
                case(L2_MODE)
                  4'b0000: begin: L2_IN_IN    // L2_out = 64-bits
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp[PT4+:PQ4] = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0];

                          out_tmp[PM4+:PQ4] = L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0];

                          out_tmp[PQ4+:PQ4] = L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0];

                          out_tmp[0+:PQ4]   = L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp[PZ2+:PQ2] = L2_out[0][0][47:32] + L2_out[0][1][47:32] + L2_out[0][2][47:32] + L2_out[0][3][47:32];
                          out_tmp[PT4+:PQ2] = L2_out[1][0][47:32] + L2_out[1][1][47:32] + L2_out[1][2][47:32] + L2_out[1][3][47:32];

                          out_tmp[PT2+:PQ2] = L2_out[2][0][47:32] + L2_out[2][1][47:32] + L2_out[2][2][47:32] + L2_out[2][3][47:32];
                          out_tmp[PM4+:PQ2] = L2_out[3][0][47:32] + L2_out[3][1][47:32] + L2_out[3][2][47:32] + L2_out[3][3][47:32];

                          out_tmp[PM2+:PQ2] = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0];
                          out_tmp[PQ4+:PQ2] = L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0];

                          out_tmp[PQ2+:PQ2] = L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0];
                          out_tmp[0+:PQ2]   = L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[PZ3+:PQ1] = L2_out[0][0][63:48] + L2_out[0][1][63:48] + L2_out[0][2][63:48] + L2_out[0][3][63:48];
                          out_tmp[PZ2+:PQ1] = L2_out[1][0][63:48] + L2_out[1][1][63:48] + L2_out[1][2][63:48] + L2_out[1][3][63:48];
                          out_tmp[PZ1+:PQ1] = L2_out[2][0][63:48] + L2_out[2][1][63:48] + L2_out[2][2][63:48] + L2_out[2][3][63:48];
                          out_tmp[PT4+:PQ1] = L2_out[3][0][63:48] + L2_out[3][1][63:48] + L2_out[3][2][63:48] + L2_out[3][3][63:48];

                          out_tmp[PT3+:PQ1] = L2_out[0][0][47:32] + L2_out[0][1][47:32] + L2_out[0][2][47:32] + L2_out[0][3][47:32];
                          out_tmp[PT2+:PQ1] = L2_out[1][0][47:32] + L2_out[1][1][47:32] + L2_out[1][2][47:32] + L2_out[1][3][47:32];
                          out_tmp[PT1+:PQ1] = L2_out[2][0][47:32] + L2_out[2][1][47:32] + L2_out[2][2][47:32] + L2_out[2][3][47:32];
                          out_tmp[PM4+:PQ1] = L2_out[3][0][47:32] + L2_out[3][1][47:32] + L2_out[3][2][47:32] + L2_out[3][3][47:32];

                          out_tmp[PM3+:PQ1] = L2_out[0][0][31:16] + L2_out[0][1][31:16] + L2_out[0][2][31:16] + L2_out[0][3][31:16];
                          out_tmp[PM2+:PQ1] = L2_out[1][0][31:16] + L2_out[1][1][31:16] + L2_out[1][2][31:16] + L2_out[1][3][31:16];
                          out_tmp[PM1+:PQ1] = L2_out[2][0][31:16] + L2_out[2][1][31:16] + L2_out[2][2][31:16] + L2_out[2][3][31:16];
                          out_tmp[PQ4+:PQ1] = L2_out[3][0][31:16] + L2_out[3][1][31:16] + L2_out[3][2][31:16] + L2_out[3][3][31:16];

                          out_tmp[PQ3+:PQ1] = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0];
                          out_tmp[PQ2+:PQ1] = L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0];
                          out_tmp[PQ1+:PQ1] = L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0];
                          out_tmp[0+:PQ1]   = L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[PZ3+:PQ1] = L2_out[0][0][63:48] + L2_out[0][1][63:48] + L2_out[0][2][63:48] + L2_out[0][3][63:48];
                          out_tmp[PZ2+:PQ1] = L2_out[1][0][63:48] + L2_out[1][1][63:48] + L2_out[1][2][63:48] + L2_out[1][3][63:48];
                          out_tmp[PZ1+:PQ1] = L2_out[2][0][63:48] + L2_out[2][1][63:48] + L2_out[2][2][63:48] + L2_out[2][3][63:48];
                          out_tmp[PT4+:PQ1] = L2_out[3][0][63:48] + L2_out[3][1][63:48] + L2_out[3][2][63:48] + L2_out[3][3][63:48];

                          out_tmp[PT3+:PQ1] = L2_out[0][0][47:32] + L2_out[0][1][47:32] + L2_out[0][2][47:32] + L2_out[0][3][47:32];
                          out_tmp[PT2+:PQ1] = L2_out[1][0][47:32] + L2_out[1][1][47:32] + L2_out[1][2][47:32] + L2_out[1][3][47:32];
                          out_tmp[PT1+:PQ1] = L2_out[2][0][47:32] + L2_out[2][1][47:32] + L2_out[2][2][47:32] + L2_out[2][3][47:32];
                          out_tmp[PM4+:PQ1] = L2_out[3][0][47:32] + L2_out[3][1][47:32] + L2_out[3][2][47:32] + L2_out[3][3][47:32];

                          out_tmp[PM3+:PQ1] = L2_out[0][0][31:16] + L2_out[0][1][31:16] + L2_out[0][2][31:16] + L2_out[0][3][31:16];
                          out_tmp[PM2+:PQ1] = L2_out[1][0][31:16] + L2_out[1][1][31:16] + L2_out[1][2][31:16] + L2_out[1][3][31:16];
                          out_tmp[PM1+:PQ1] = L2_out[2][0][31:16] + L2_out[2][1][31:16] + L2_out[2][2][31:16] + L2_out[2][3][31:16];
                          out_tmp[PQ4+:PQ1] = L2_out[3][0][31:16] + L2_out[3][1][31:16] + L2_out[3][2][31:16] + L2_out[3][3][31:16];

                          out_tmp[PQ3+:PQ1] = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0];
                          out_tmp[PQ2+:PQ1] = L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0];
                          out_tmp[PQ1+:PQ1] = L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0];
                          out_tmp[0+:PQ1]   = L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[PZ3+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][63:60] + L2_out[0][1][63:60] + L2_out[0][2][63:60] + L2_out[0][3][63:60];
                          out_tmp[PZ3+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][63:60] + L2_out[1][1][63:60] + L2_out[1][2][63:60] + L2_out[1][3][63:60];
                          out_tmp[PZ3+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][63:60] + L2_out[2][1][63:60] + L2_out[2][2][63:60] + L2_out[2][3][63:60];
                          out_tmp[PZ3+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][63:60] + L2_out[3][1][63:60] + L2_out[3][2][63:60] + L2_out[3][3][63:60];
                          
                          out_tmp[PZ2+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][59:56] + L2_out[0][1][59:56] + L2_out[0][2][59:56] + L2_out[0][3][59:56];
                          out_tmp[PZ2+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][59:56] + L2_out[1][1][59:56] + L2_out[1][2][59:56] + L2_out[1][3][59:56];
                          out_tmp[PZ2+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][59:56] + L2_out[2][1][59:56] + L2_out[2][2][59:56] + L2_out[2][3][59:56];
                          out_tmp[PZ2+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][59:56] + L2_out[3][1][59:56] + L2_out[3][2][59:56] + L2_out[3][3][59:56];

                          out_tmp[PZ1+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][55:52] + L2_out[0][1][55:52] + L2_out[0][2][55:52] + L2_out[0][3][55:52];
                          out_tmp[PZ1+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][55:52] + L2_out[1][1][55:52] + L2_out[1][2][55:52] + L2_out[1][3][55:52];
                          out_tmp[PZ1+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][55:52] + L2_out[2][1][55:52] + L2_out[2][2][55:52] + L2_out[2][3][55:52];
                          out_tmp[PZ1+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][55:52] + L2_out[3][1][55:52] + L2_out[3][2][55:52] + L2_out[3][3][55:52];

                          out_tmp[PT4+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][51:48] + L2_out[0][1][51:48] + L2_out[0][2][51:48] + L2_out[0][3][51:48];
                          out_tmp[PT4+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][51:48] + L2_out[1][1][51:48] + L2_out[1][2][51:48] + L2_out[1][3][51:48];
                          out_tmp[PT4+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][51:48] + L2_out[2][1][51:48] + L2_out[2][2][51:48] + L2_out[2][3][51:48];
                          out_tmp[PT4+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][51:48] + L2_out[3][1][51:48] + L2_out[3][2][51:48] + L2_out[3][3][51:48];

                          // BREAK! 

                          out_tmp[PT3+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][47:44] + L2_out[0][1][47:44] + L2_out[0][2][47:44] + L2_out[0][3][47:44];
                          out_tmp[PT3+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][47:44] + L2_out[1][1][47:44] + L2_out[1][2][47:44] + L2_out[1][3][47:44];
                          out_tmp[PT3+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][47:44] + L2_out[2][1][47:44] + L2_out[2][2][47:44] + L2_out[2][3][47:44];
                          out_tmp[PT3+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][47:44] + L2_out[3][1][47:44] + L2_out[3][2][47:44] + L2_out[3][3][47:44];
                          
                          out_tmp[PT2+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][43:40] + L2_out[0][1][43:40] + L2_out[0][2][43:40] + L2_out[0][3][43:40];
                          out_tmp[PT2+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][43:40] + L2_out[1][1][43:40] + L2_out[1][2][43:40] + L2_out[1][3][43:40];
                          out_tmp[PT2+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][43:40] + L2_out[2][1][43:40] + L2_out[2][2][43:40] + L2_out[2][3][43:40];
                          out_tmp[PT2+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][43:40] + L2_out[3][1][43:40] + L2_out[3][2][43:40] + L2_out[3][3][43:40];

                          out_tmp[PT1+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][39:36] + L2_out[0][1][39:36] + L2_out[0][2][39:36] + L2_out[0][3][39:36];
                          out_tmp[PT1+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][39:36] + L2_out[1][1][39:36] + L2_out[1][2][39:36] + L2_out[1][3][39:36];
                          out_tmp[PT1+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][39:36] + L2_out[2][1][39:36] + L2_out[2][2][39:36] + L2_out[2][3][39:36];
                          out_tmp[PT1+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][39:36] + L2_out[3][1][39:36] + L2_out[3][2][39:36] + L2_out[3][3][39:36];

                          out_tmp[PM4+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][35:32] + L2_out[0][1][35:32] + L2_out[0][2][35:32] + L2_out[0][3][35:32];
                          out_tmp[PM4+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][35:32] + L2_out[1][1][35:32] + L2_out[1][2][35:32] + L2_out[1][3][35:32];
                          out_tmp[PM4+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][35:32] + L2_out[2][1][35:32] + L2_out[2][2][35:32] + L2_out[2][3][35:32];
                          out_tmp[PM4+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][35:32] + L2_out[3][1][35:32] + L2_out[3][2][35:32] + L2_out[3][3][35:32];
                          
                          // BREAK! 

                          out_tmp[PM3+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][31:28] + L2_out[0][1][31:28] + L2_out[0][2][31:28] + L2_out[0][3][31:28];
                          out_tmp[PM3+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][31:28] + L2_out[1][1][31:28] + L2_out[1][2][31:28] + L2_out[1][3][31:28];
                          out_tmp[PM3+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][31:28] + L2_out[2][1][31:28] + L2_out[2][2][31:28] + L2_out[2][3][31:28];
                          out_tmp[PM3+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][31:28] + L2_out[3][1][31:28] + L2_out[3][2][31:28] + L2_out[3][3][31:28];
                          
                          out_tmp[PM2+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][27:24] + L2_out[0][1][27:24] + L2_out[0][2][27:24] + L2_out[0][3][27:24];
                          out_tmp[PM2+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][27:24] + L2_out[1][1][27:24] + L2_out[1][2][27:24] + L2_out[1][3][27:24];
                          out_tmp[PM2+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][27:24] + L2_out[2][1][27:24] + L2_out[2][2][27:24] + L2_out[2][3][27:24];
                          out_tmp[PM2+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][27:24] + L2_out[3][1][27:24] + L2_out[3][2][27:24] + L2_out[3][3][27:24];

                          out_tmp[PM1+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][23:20] + L2_out[0][1][23:20] + L2_out[0][2][23:20] + L2_out[0][3][23:20];
                          out_tmp[PM1+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][23:20] + L2_out[1][1][23:20] + L2_out[1][2][23:20] + L2_out[1][3][23:20];
                          out_tmp[PM1+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][23:20] + L2_out[2][1][23:20] + L2_out[2][2][23:20] + L2_out[2][3][23:20];
                          out_tmp[PM1+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][23:20] + L2_out[3][1][23:20] + L2_out[3][2][23:20] + L2_out[3][3][23:20];

                          out_tmp[PQ4+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][19:16] + L2_out[0][1][19:16] + L2_out[0][2][19:16] + L2_out[0][3][19:16];
                          out_tmp[PQ4+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][19:16] + L2_out[1][1][19:16] + L2_out[1][2][19:16] + L2_out[1][3][19:16];
                          out_tmp[PQ4+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][19:16] + L2_out[2][1][19:16] + L2_out[2][2][19:16] + L2_out[2][3][19:16];
                          out_tmp[PQ4+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][19:16] + L2_out[3][1][19:16] + L2_out[3][2][19:16] + L2_out[3][3][19:16];
                          
                          // BREAK! 

                          out_tmp[PQ3+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][15:12] + L2_out[0][1][15:12] + L2_out[0][2][15:12] + L2_out[0][3][15:12];
                          out_tmp[PQ3+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][15:12] + L2_out[1][1][15:12] + L2_out[1][2][15:12] + L2_out[1][3][15:12];
                          out_tmp[PQ3+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][15:12] + L2_out[2][1][15:12] + L2_out[2][2][15:12] + L2_out[2][3][15:12];
                          out_tmp[PQ3+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][15:12] + L2_out[3][1][15:12] + L2_out[3][2][15:12] + L2_out[3][3][15:12];
                          
                          out_tmp[PQ2+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][11:8] + L2_out[0][1][11:8] + L2_out[0][2][11:8] + L2_out[0][3][11:8];
                          out_tmp[PQ2+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][11:8] + L2_out[1][1][11:8] + L2_out[1][2][11:8] + L2_out[1][3][11:8];
                          out_tmp[PQ2+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][11:8] + L2_out[2][1][11:8] + L2_out[2][2][11:8] + L2_out[2][3][11:8];
                          out_tmp[PQ2+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][11:8] + L2_out[3][1][11:8] + L2_out[3][2][11:8] + L2_out[3][3][11:8];

                          out_tmp[PQ1+(PQ1*3/4)+:(PQ1/4)] = L2_out[0][0][7:4] + L2_out[0][1][7:4] + L2_out[0][2][7:4] + L2_out[0][3][7:4];
                          out_tmp[PQ1+(PQ1*2/4)+:(PQ1/4)] = L2_out[1][0][7:4] + L2_out[1][1][7:4] + L2_out[1][2][7:4] + L2_out[1][3][7:4];
                          out_tmp[PQ1+(PQ1*1/4)+:(PQ1/4)] = L2_out[2][0][7:4] + L2_out[2][1][7:4] + L2_out[2][2][7:4] + L2_out[2][3][7:4];
                          out_tmp[PQ1+(PQ1*0/4)+:(PQ1/4)] = L2_out[3][0][7:4] + L2_out[3][1][7:4] + L2_out[3][2][7:4] + L2_out[3][3][7:4];

                          out_tmp[0+(PQ1*3/4)+:(PQ1/4)]   = L2_out[0][0][3:0] + L2_out[0][1][3:0] + L2_out[0][2][3:0] + L2_out[0][3][3:0];
                          out_tmp[0+(PQ1*2/4)+:(PQ1/4)]   = L2_out[1][0][3:0] + L2_out[1][1][3:0] + L2_out[1][2][3:0] + L2_out[1][3][3:0];
                          out_tmp[0+(PQ1*1/4)+:(PQ1/4)]   = L2_out[2][0][3:0] + L2_out[2][1][3:0] + L2_out[2][2][3:0] + L2_out[2][3][3:0];
                          out_tmp[0+(PQ1*0/4)+:(PQ1/4)]   = L2_out[3][0][3:0] + L2_out[3][1][3:0] + L2_out[3][2][3:0] + L2_out[3][3][3:0];
                        end
                      endcase
                    end
                  end
                  4'b1010: begin: L2_OUT_IN     // L2_out = 24-bits
                    always_comb begin
                      unique case(prec[3:2])  // MSB of prec
                        2'b00: begin  // 8bx8b, 8bx4b, 8bx2b produce only 1 result each 
                          out_tmp[PT4+:PQ4] = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0];

                          out_tmp[PM4+:PQ4] = L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0];

                          out_tmp[PQ4+:PQ4] = L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0];

                          out_tmp[0+:PQ4]   = L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        2'b10: begin  // 4bx4b
                          out_tmp[PZ2+:PQ2] = L2_out[0][0][M+:M] + L2_out[0][1][M+:M] + L2_out[0][2][M+:M] + L2_out[0][3][M+:M];
                          out_tmp[PT4+:PQ2] = L2_out[1][0][M+:M] + L2_out[1][1][M+:M] + L2_out[1][2][M+:M] + L2_out[1][3][M+:M];

                          out_tmp[PT2+:PQ2] = L2_out[2][0][M+:M] + L2_out[2][1][M+:M] + L2_out[2][2][M+:M] + L2_out[2][3][M+:M];
                          out_tmp[PM4+:PQ2] = L2_out[3][0][M+:M] + L2_out[3][1][M+:M] + L2_out[3][2][M+:M] + L2_out[3][3][M+:M];

                          out_tmp[PM2+:PQ2] = L2_out[0][0][0+:M] + L2_out[0][1][0+:M] + L2_out[0][2][0+:M] + L2_out[0][3][0+:M];
                          out_tmp[PQ4+:PQ2] = L2_out[1][0][0+:M] + L2_out[1][1][0+:M] + L2_out[1][2][0+:M] + L2_out[1][3][0+:M];

                          out_tmp[PQ2+:PQ2] = L2_out[2][0][0+:M] + L2_out[2][1][0+:M] + L2_out[2][2][0+:M] + L2_out[2][3][0+:M];
                          out_tmp[0+:PQ2]   = L2_out[3][0][0+:M] + L2_out[3][1][0+:M] + L2_out[3][2][0+:M] + L2_out[3][3][0+:M];
                        end
                        2'b11: begin  // 2bx2b
                          out_tmp[PZ3+:PQ1] = L2_out[0][0][T+:Q] + L2_out[0][1][T+:Q] + L2_out[0][2][T+:Q] + L2_out[0][3][T+:Q];
                          out_tmp[PZ2+:PQ1] = L2_out[1][0][T+:Q] + L2_out[1][1][T+:Q] + L2_out[1][2][T+:Q] + L2_out[1][3][T+:Q];
                          out_tmp[PZ1+:PQ1] = L2_out[2][0][T+:Q] + L2_out[2][1][T+:Q] + L2_out[2][2][T+:Q] + L2_out[2][3][T+:Q];
                          out_tmp[PT4+:PQ1] = L2_out[3][0][T+:Q] + L2_out[3][1][T+:Q] + L2_out[3][2][T+:Q] + L2_out[3][3][T+:Q];

                          out_tmp[PT3+:PQ1] = L2_out[0][0][M+:Q] + L2_out[0][1][M+:Q] + L2_out[0][2][M+:Q] + L2_out[0][3][M+:Q];
                          out_tmp[PT2+:PQ1] = L2_out[1][0][M+:Q] + L2_out[1][1][M+:Q] + L2_out[1][2][M+:Q] + L2_out[1][3][M+:Q];
                          out_tmp[PT1+:PQ1] = L2_out[2][0][M+:Q] + L2_out[2][1][M+:Q] + L2_out[2][2][M+:Q] + L2_out[2][3][M+:Q];
                          out_tmp[PM4+:PQ1] = L2_out[3][0][M+:Q] + L2_out[3][1][M+:Q] + L2_out[3][2][M+:Q] + L2_out[3][3][M+:Q];

                          out_tmp[PM3+:PQ1] = L2_out[0][0][Q+:Q] + L2_out[0][1][Q+:Q] + L2_out[0][2][Q+:Q] + L2_out[0][3][Q+:Q];
                          out_tmp[PM2+:PQ1] = L2_out[1][0][Q+:Q] + L2_out[1][1][Q+:Q] + L2_out[1][2][Q+:Q] + L2_out[1][3][Q+:Q];
                          out_tmp[PM1+:PQ1] = L2_out[2][0][Q+:Q] + L2_out[2][1][Q+:Q] + L2_out[2][2][Q+:Q] + L2_out[2][3][Q+:Q];
                          out_tmp[PQ4+:PQ1] = L2_out[3][0][Q+:Q] + L2_out[3][1][Q+:Q] + L2_out[3][2][Q+:Q] + L2_out[3][3][Q+:Q];

                          out_tmp[PQ3+:PQ1] = L2_out[0][0][0+:Q] + L2_out[0][1][0+:Q] + L2_out[0][2][0+:Q] + L2_out[0][3][0+:Q];
                          out_tmp[PQ2+:PQ1] = L2_out[1][0][0+:Q] + L2_out[1][1][0+:Q] + L2_out[1][2][0+:Q] + L2_out[1][3][0+:Q];
                          out_tmp[PQ1+:PQ1] = L2_out[2][0][0+:Q] + L2_out[2][1][0+:Q] + L2_out[2][2][0+:Q] + L2_out[2][3][0+:Q];
                          out_tmp[0+:PQ1]   = L2_out[3][0][0+:Q] + L2_out[3][1][0+:Q] + L2_out[3][2][0+:Q] + L2_out[3][3][0+:Q];
                        end
                      endcase
                    end
                  end
                  4'b1111: begin: L2_OUT_OUT
                    // Doesn't care about precision - L2 always produces 1 out 
                    always_comb begin
                      out_tmp[PT4+:PQ4] = L2_out[0][0] + L2_out[0][1] + L2_out[0][2] + L2_out[0][3];
                      out_tmp[PM4+:PQ4] = L2_out[1][0] + L2_out[1][1] + L2_out[1][2] + L2_out[1][3];
                      out_tmp[PQ4+:PQ4] = L2_out[2][0] + L2_out[2][1] + L2_out[2][2] + L2_out[2][3];
                      out_tmp[0+:PQ4]   = L2_out[3][0] + L2_out[3][1] + L2_out[3][2] + L2_out[3][3];
                    end
                  end
                endcase
              end
              2'b11: begin: L3_OUT_OUT
                always_comb begin
                  L2_w = '{'{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][2], w[2][2], w[1][2], w[0][2]}, 
                           '{w[3][1], w[2][1], w[1][1], w[0][1]}, 
                           '{w[3][3], w[2][3], w[1][3], w[0][3]}};
                  
                  L2_a = '{'{a[0][0], a[0][2], a[0][1], a[0][3]}, 
                           '{a[1][0], a[1][2], a[1][1], a[1][3]}, 
                           '{a[2][0], a[2][2], a[2][1], a[2][3]}, 
                           '{a[3][0], a[3][2], a[3][1], a[3][3]}};
                end
                case(L2_MODE)
                  4'b0000: begin: L2_IN_IN
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0]
                                  + L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0]
                                  + L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0]
                                  + L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp[PM4+:PM4] = L2_out[0][0][47:32] + L2_out[0][1][47:32] + L2_out[0][2][47:32] + L2_out[0][3][47:32]
                                            + L2_out[1][0][47:32] + L2_out[1][1][47:32] + L2_out[1][2][47:32] + L2_out[1][3][47:32]
                                            + L2_out[2][0][47:32] + L2_out[2][1][47:32] + L2_out[2][2][47:32] + L2_out[2][3][47:32]
                                            + L2_out[3][0][47:32] + L2_out[3][1][47:32] + L2_out[3][2][47:32] + L2_out[3][3][47:32];

                          out_tmp[0+:PM4]   = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0]
                                            + L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0]
                                            + L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0]
                                            + L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[PT4+:PQ4] = L2_out[0][0][63:48] + L2_out[0][1][63:48] + L2_out[0][2][63:48] + L2_out[0][3][63:48]
                                            + L2_out[1][0][63:48] + L2_out[1][1][63:48] + L2_out[1][2][63:48] + L2_out[1][3][63:48]
                                            + L2_out[2][0][63:48] + L2_out[2][1][63:48] + L2_out[2][2][63:48] + L2_out[2][3][63:48]
                                            + L2_out[3][0][63:48] + L2_out[3][1][63:48] + L2_out[3][2][63:48] + L2_out[3][3][63:48];

                          out_tmp[PM4+:PQ4] = L2_out[0][0][47:32] + L2_out[0][1][47:32] + L2_out[0][2][47:32] + L2_out[0][3][47:32]
                                            + L2_out[1][0][47:32] + L2_out[1][1][47:32] + L2_out[1][2][47:32] + L2_out[1][3][47:32]
                                            + L2_out[2][0][47:32] + L2_out[2][1][47:32] + L2_out[2][2][47:32] + L2_out[2][3][47:32]
                                            + L2_out[3][0][47:32] + L2_out[3][1][47:32] + L2_out[3][2][47:32] + L2_out[3][3][47:32];

                          out_tmp[PQ4+:PQ4] = L2_out[0][0][31:16] + L2_out[0][1][31:16] + L2_out[0][2][31:16] + L2_out[0][3][31:16]
                                            + L2_out[1][0][31:16] + L2_out[1][1][31:16] + L2_out[1][2][31:16] + L2_out[1][3][31:16]
                                            + L2_out[2][0][31:16] + L2_out[2][1][31:16] + L2_out[2][2][31:16] + L2_out[2][3][31:16]
                                            + L2_out[3][0][31:16] + L2_out[3][1][31:16] + L2_out[3][2][31:16] + L2_out[3][3][31:16];

                          out_tmp[0+:PQ4]   = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0]
                                            + L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0]
                                            + L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0]
                                            + L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[PT4+:PQ4] = L2_out[0][0][63:48] + L2_out[0][1][63:48] + L2_out[0][2][63:48] + L2_out[0][3][63:48]
                                            + L2_out[1][0][63:48] + L2_out[1][1][63:48] + L2_out[1][2][63:48] + L2_out[1][3][63:48]
                                            + L2_out[2][0][63:48] + L2_out[2][1][63:48] + L2_out[2][2][63:48] + L2_out[2][3][63:48]
                                            + L2_out[3][0][63:48] + L2_out[3][1][63:48] + L2_out[3][2][63:48] + L2_out[3][3][63:48];

                          out_tmp[PM4+:PQ4] = L2_out[0][0][47:32] + L2_out[0][1][47:32] + L2_out[0][2][47:32] + L2_out[0][3][47:32]
                                            + L2_out[1][0][47:32] + L2_out[1][1][47:32] + L2_out[1][2][47:32] + L2_out[1][3][47:32]
                                            + L2_out[2][0][47:32] + L2_out[2][1][47:32] + L2_out[2][2][47:32] + L2_out[2][3][47:32]
                                            + L2_out[3][0][47:32] + L2_out[3][1][47:32] + L2_out[3][2][47:32] + L2_out[3][3][47:32];

                          out_tmp[PQ4+:PQ4] = L2_out[0][0][31:16] + L2_out[0][1][31:16] + L2_out[0][2][31:16] + L2_out[0][3][31:16]
                                            + L2_out[1][0][31:16] + L2_out[1][1][31:16] + L2_out[1][2][31:16] + L2_out[1][3][31:16]
                                            + L2_out[2][0][31:16] + L2_out[2][1][31:16] + L2_out[2][2][31:16] + L2_out[2][3][31:16]
                                            + L2_out[3][0][31:16] + L2_out[3][1][31:16] + L2_out[3][2][31:16] + L2_out[3][3][31:16];

                          out_tmp[0+:PQ4]   = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0]
                                            + L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0]
                                            + L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0]
                                            + L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[PZ3+:PQ1] = L2_out[0][0][63:60] + L2_out[0][1][63:60] + L2_out[0][2][63:60] + L2_out[0][3][63:60]
                                            + L2_out[1][0][63:60] + L2_out[1][1][63:60] + L2_out[1][2][63:60] + L2_out[1][3][63:60]
                                            + L2_out[2][0][63:60] + L2_out[2][1][63:60] + L2_out[2][2][63:60] + L2_out[2][3][63:60]
                                            + L2_out[3][0][63:60] + L2_out[3][1][63:60] + L2_out[3][2][63:60] + L2_out[3][3][63:60];
                          
                          out_tmp[PZ2+:PQ1] = L2_out[0][0][59:56] + L2_out[0][1][59:56] + L2_out[0][2][59:56] + L2_out[0][3][59:56]
                                            + L2_out[1][0][59:56] + L2_out[1][1][59:56] + L2_out[1][2][59:56] + L2_out[1][3][59:56]
                                            + L2_out[2][0][59:56] + L2_out[2][1][59:56] + L2_out[2][2][59:56] + L2_out[2][3][59:56]
                                            + L2_out[3][0][59:56] + L2_out[3][1][59:56] + L2_out[3][2][59:56] + L2_out[3][3][59:56];

                          out_tmp[PZ1+:PQ1] = L2_out[0][0][55:52] + L2_out[0][1][55:52] + L2_out[0][2][55:52] + L2_out[0][3][55:52]
                                            + L2_out[1][0][55:52] + L2_out[1][1][55:52] + L2_out[1][2][55:52] + L2_out[1][3][55:52]
                                            + L2_out[2][0][55:52] + L2_out[2][1][55:52] + L2_out[2][2][55:52] + L2_out[2][3][55:52]
                                            + L2_out[3][0][55:52] + L2_out[3][1][55:52] + L2_out[3][2][55:52] + L2_out[3][3][55:52];

                          out_tmp[PT4+:PQ1] = L2_out[0][0][51:48] + L2_out[0][1][51:48] + L2_out[0][2][51:48] + L2_out[0][3][51:48]
                                            + L2_out[1][0][51:48] + L2_out[1][1][51:48] + L2_out[1][2][51:48] + L2_out[1][3][51:48]
                                            + L2_out[2][0][51:48] + L2_out[2][1][51:48] + L2_out[2][2][51:48] + L2_out[2][3][51:48]
                                            + L2_out[3][0][51:48] + L2_out[3][1][51:48] + L2_out[3][2][51:48] + L2_out[3][3][51:48];

                          // BREAK! 

                          out_tmp[PT3+:PQ1] = L2_out[0][0][47:44] + L2_out[0][1][47:44] + L2_out[0][2][47:44] + L2_out[0][3][47:44]
                                            + L2_out[1][0][47:44] + L2_out[1][1][47:44] + L2_out[1][2][47:44] + L2_out[1][3][47:44]
                                            + L2_out[2][0][47:44] + L2_out[2][1][47:44] + L2_out[2][2][47:44] + L2_out[2][3][47:44]
                                            + L2_out[3][0][47:44] + L2_out[3][1][47:44] + L2_out[3][2][47:44] + L2_out[3][3][47:44];
                          
                          out_tmp[PT2+:PQ1] = L2_out[0][0][43:40] + L2_out[0][1][43:40] + L2_out[0][2][43:40] + L2_out[0][3][43:40]
                                            + L2_out[1][0][43:40] + L2_out[1][1][43:40] + L2_out[1][2][43:40] + L2_out[1][3][43:40]
                                            + L2_out[2][0][43:40] + L2_out[2][1][43:40] + L2_out[2][2][43:40] + L2_out[2][3][43:40]
                                            + L2_out[3][0][43:40] + L2_out[3][1][43:40] + L2_out[3][2][43:40] + L2_out[3][3][43:40];

                          out_tmp[PT1+:PQ1] = L2_out[0][0][39:36] + L2_out[0][1][39:36] + L2_out[0][2][39:36] + L2_out[0][3][39:36]
                                            + L2_out[1][0][39:36] + L2_out[1][1][39:36] + L2_out[1][2][39:36] + L2_out[1][3][39:36]
                                            + L2_out[2][0][39:36] + L2_out[2][1][39:36] + L2_out[2][2][39:36] + L2_out[2][3][39:36]
                                            + L2_out[3][0][39:36] + L2_out[3][1][39:36] + L2_out[3][2][39:36] + L2_out[3][3][39:36];

                          out_tmp[PM4+:PQ1] = L2_out[0][0][35:32] + L2_out[0][1][35:32] + L2_out[0][2][35:32] + L2_out[0][3][35:32]
                                            + L2_out[1][0][35:32] + L2_out[1][1][35:32] + L2_out[1][2][35:32] + L2_out[1][3][35:32]
                                            + L2_out[2][0][35:32] + L2_out[2][1][35:32] + L2_out[2][2][35:32] + L2_out[2][3][35:32]
                                            + L2_out[3][0][35:32] + L2_out[3][1][35:32] + L2_out[3][2][35:32] + L2_out[3][3][35:32];
                          
                          // BREAK! 

                          out_tmp[PM3+:PQ1] = L2_out[0][0][31:28] + L2_out[0][1][31:28] + L2_out[0][2][31:28] + L2_out[0][3][31:28]
                                            + L2_out[1][0][31:28] + L2_out[1][1][31:28] + L2_out[1][2][31:28] + L2_out[1][3][31:28]
                                            + L2_out[2][0][31:28] + L2_out[2][1][31:28] + L2_out[2][2][31:28] + L2_out[2][3][31:28]
                                            + L2_out[3][0][31:28] + L2_out[3][1][31:28] + L2_out[3][2][31:28] + L2_out[3][3][31:28];
                          
                          out_tmp[PM2+:PQ1] = L2_out[0][0][27:24] + L2_out[0][1][27:24] + L2_out[0][2][27:24] + L2_out[0][3][27:24]
                                            + L2_out[1][0][27:24] + L2_out[1][1][27:24] + L2_out[1][2][27:24] + L2_out[1][3][27:24]
                                            + L2_out[2][0][27:24] + L2_out[2][1][27:24] + L2_out[2][2][27:24] + L2_out[2][3][27:24]
                                            + L2_out[3][0][27:24] + L2_out[3][1][27:24] + L2_out[3][2][27:24] + L2_out[3][3][27:24];

                          out_tmp[PM1+:PQ1] = L2_out[0][0][23:20] + L2_out[0][1][23:20] + L2_out[0][2][23:20] + L2_out[0][3][23:20]
                                            + L2_out[1][0][23:20] + L2_out[1][1][23:20] + L2_out[1][2][23:20] + L2_out[1][3][23:20]
                                            + L2_out[2][0][23:20] + L2_out[2][1][23:20] + L2_out[2][2][23:20] + L2_out[2][3][23:20]
                                            + L2_out[3][0][23:20] + L2_out[3][1][23:20] + L2_out[3][2][23:20] + L2_out[3][3][23:20];

                          out_tmp[PQ4+:PQ1] = L2_out[0][0][19:16] + L2_out[0][1][19:16] + L2_out[0][2][19:16] + L2_out[0][3][19:16]
                                            + L2_out[1][0][19:16] + L2_out[1][1][19:16] + L2_out[1][2][19:16] + L2_out[1][3][19:16]
                                            + L2_out[2][0][19:16] + L2_out[2][1][19:16] + L2_out[2][2][19:16] + L2_out[2][3][19:16]
                                            + L2_out[3][0][19:16] + L2_out[3][1][19:16] + L2_out[3][2][19:16] + L2_out[3][3][19:16];
                          
                          // BREAK! 

                          out_tmp[PQ3+:PQ1] = L2_out[0][0][15:12] + L2_out[0][1][15:12] + L2_out[0][2][15:12] + L2_out[0][3][15:12]
                                            + L2_out[1][0][15:12] + L2_out[1][1][15:12] + L2_out[1][2][15:12] + L2_out[1][3][15:12]
                                            + L2_out[2][0][15:12] + L2_out[2][1][15:12] + L2_out[2][2][15:12] + L2_out[2][3][15:12]
                                            + L2_out[3][0][15:12] + L2_out[3][1][15:12] + L2_out[3][2][15:12] + L2_out[3][3][15:12];
                          
                          out_tmp[PQ2+:PQ1] = L2_out[0][0][11:8] + L2_out[0][1][11:8] + L2_out[0][2][11:8] + L2_out[0][3][11:8]
                                            + L2_out[1][0][11:8] + L2_out[1][1][11:8] + L2_out[1][2][11:8] + L2_out[1][3][11:8]
                                            + L2_out[2][0][11:8] + L2_out[2][1][11:8] + L2_out[2][2][11:8] + L2_out[2][3][11:8]
                                            + L2_out[3][0][11:8] + L2_out[3][1][11:8] + L2_out[3][2][11:8] + L2_out[3][3][11:8];

                          out_tmp[PQ1+:PQ1] = L2_out[0][0][7:4] + L2_out[0][1][7:4] + L2_out[0][2][7:4] + L2_out[0][3][7:4]
                                            + L2_out[1][0][7:4] + L2_out[1][1][7:4] + L2_out[1][2][7:4] + L2_out[1][3][7:4]
                                            + L2_out[2][0][7:4] + L2_out[2][1][7:4] + L2_out[2][2][7:4] + L2_out[2][3][7:4]
                                            + L2_out[3][0][7:4] + L2_out[3][1][7:4] + L2_out[3][2][7:4] + L2_out[3][3][7:4];

                          out_tmp[0+:PQ1]   = L2_out[0][0][3:0] + L2_out[0][1][3:0] + L2_out[0][2][3:0] + L2_out[0][3][3:0]
                                            + L2_out[1][0][3:0] + L2_out[1][1][3:0] + L2_out[1][2][3:0] + L2_out[1][3][3:0]
                                            + L2_out[2][0][3:0] + L2_out[2][1][3:0] + L2_out[2][2][3:0] + L2_out[2][3][3:0]
                                            + L2_out[3][0][3:0] + L2_out[3][1][3:0] + L2_out[3][2][3:0] + L2_out[3][3][3:0];
                        end
                      endcase
                    end
                  end
                  4'b1010: begin: L2_OUT_IN
                    always_comb begin
                      unique case(prec[3:2])  // MSB of prec
                        2'b00: begin  // 8bx8b, 8bx4b, 8bx2b produce only 1 result each 
                          out_tmp = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0]
                              + L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0]
                              + L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0]
                              + L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        2'b10: begin  // 4bx4b
                          out_tmp[PM4+:PM4] = L2_out[0][0][M+:M] + L2_out[0][1][M+:M] + L2_out[0][2][M+:M] + L2_out[0][3][M+:M]
                                    + L2_out[1][0][M+:M] + L2_out[1][1][M+:M] + L2_out[1][2][M+:M] + L2_out[1][3][M+:M]
                                    + L2_out[2][0][M+:M] + L2_out[2][1][M+:M] + L2_out[2][2][M+:M] + L2_out[2][3][M+:M]
                                    + L2_out[3][0][M+:M] + L2_out[3][1][M+:M] + L2_out[3][2][M+:M] + L2_out[3][3][M+:M];
                          
                          out_tmp[0+:PM4]   = L2_out[0][0][0+:M] + L2_out[0][1][0+:M] + L2_out[0][2][0+:M] + L2_out[0][3][0+:M]
                                    + L2_out[1][0][0+:M] + L2_out[1][1][0+:M] + L2_out[1][2][0+:M] + L2_out[1][3][0+:M]
                                    + L2_out[2][0][0+:M] + L2_out[2][1][0+:M] + L2_out[2][2][0+:M] + L2_out[2][3][0+:M]
                                    + L2_out[3][0][0+:M] + L2_out[3][1][0+:M] + L2_out[3][2][0+:M] + L2_out[3][3][0+:M];
                        end
                        2'b11: begin  // 2bx2b
                          out_tmp[PT4+:PQ4] = L2_out[0][0][T+:Q] + L2_out[0][1][T+:Q] + L2_out[0][2][T+:Q] + L2_out[0][3][T+:Q]
                                    + L2_out[1][0][T+:Q] + L2_out[1][1][T+:Q] + L2_out[1][2][T+:Q] + L2_out[1][3][T+:Q]
                                    + L2_out[2][0][T+:Q] + L2_out[2][1][T+:Q] + L2_out[2][2][T+:Q] + L2_out[2][3][T+:Q]
                                    + L2_out[3][0][T+:Q] + L2_out[3][1][T+:Q] + L2_out[3][2][T+:Q] + L2_out[3][3][T+:Q];

                          out_tmp[PM4+:PQ4] = L2_out[0][0][M+:Q] + L2_out[0][1][M+:Q] + L2_out[0][2][M+:Q] + L2_out[0][3][M+:Q]
                                    + L2_out[1][0][M+:Q] + L2_out[1][1][M+:Q] + L2_out[1][2][M+:Q] + L2_out[1][3][M+:Q]
                                    + L2_out[2][0][M+:Q] + L2_out[2][1][M+:Q] + L2_out[2][2][M+:Q] + L2_out[2][3][M+:Q]
                                    + L2_out[3][0][M+:Q] + L2_out[3][1][M+:Q] + L2_out[3][2][M+:Q] + L2_out[3][3][M+:Q];

                          out_tmp[PQ4+:PQ4] = L2_out[0][0][Q+:Q] + L2_out[0][1][Q+:Q] + L2_out[0][2][Q+:Q] + L2_out[0][3][Q+:Q]
                                    + L2_out[1][0][Q+:Q] + L2_out[1][1][Q+:Q] + L2_out[1][2][Q+:Q] + L2_out[1][3][Q+:Q]
                                    + L2_out[2][0][Q+:Q] + L2_out[2][1][Q+:Q] + L2_out[2][2][Q+:Q] + L2_out[2][3][Q+:Q]
                                    + L2_out[3][0][Q+:Q] + L2_out[3][1][Q+:Q] + L2_out[3][2][Q+:Q] + L2_out[3][3][Q+:Q];

                          out_tmp[0+:PQ4]   = L2_out[0][0][0+:Q] + L2_out[0][1][0+:Q] + L2_out[0][2][0+:Q] + L2_out[0][3][0+:Q]
                                    + L2_out[1][0][0+:Q] + L2_out[1][1][0+:Q] + L2_out[1][2][0+:Q] + L2_out[1][3][0+:Q]
                                    + L2_out[2][0][0+:Q] + L2_out[2][1][0+:Q] + L2_out[2][2][0+:Q] + L2_out[2][3][0+:Q]
                                    + L2_out[3][0][0+:Q] + L2_out[3][1][0+:Q] + L2_out[3][2][0+:Q] + L2_out[3][3][0+:Q];
                        end
                      endcase
                    end
                  end
                  4'b1111: begin: L2_OUT_OUT
                    always_comb begin
                      out_tmp = L2_out[0][0] + L2_out[0][1] + L2_out[0][2] + L2_out[0][3]
                          + L2_out[1][0] + L2_out[1][1] + L2_out[1][2] + L2_out[1][3]
                          + L2_out[2][0] + L2_out[2][1] + L2_out[2][2] + L2_out[2][3]
                          + L2_out[3][0] + L2_out[3][1] + L2_out[3][2] + L2_out[3][3];
                    end
                  end 
                endcase
              end
            endcase
          end
          
          1'b1: begin: BG_L3   // BG_01: Shifters in L3 unit
            case(L3_MODE)
              2'b00: begin: L3_IN_IN
                always_comb begin
                  // Broadcast Inputs! 
                  L2_w = '{'{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}};
                  
                  L2_a = '{'{a[0][0], a[0][0], a[0][0], a[0][0]}, 
                           '{a[1][0], a[1][0], a[1][0], a[1][0]}, 
                           '{a[2][0], a[2][0], a[2][0], a[2][0]}, 
                           '{a[3][0], a[3][0], a[3][0], a[3][0]}}; 
                end
                case(L2_MODE)
                  4'b0000: begin: L2_IN_IN
                    // NOTE: Same as BG_L2 - Redundant! 
                    // BG_L2: 4x4 L2 units, each having an add/shift tree (total = 16)
                    // BG_L3: Each L2 produces 16 outputs, requiring 16 add/shift trees in L3 (total = 16)
                    // As a result, no savings what so ever 
                  end
                  4'b1010: begin: L2_OUT_IN   // L2_out = 4x6-bits = 24-bits
                    // L2 produces 4 outputs - instead of 16 add/shift trees, we only need 4
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b // NOTE: FIXED! 
                          out_tmp[PT4+:PQ4] = {{L2_out[0][0][T+:Q], 2'b0} + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 4'b0} + {L2_out[1][1][T+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][T+:Q], 2'b0} + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 4'b0} + {L2_out[1][3][T+:Q], 2'b0}}
                                    + {{L2_out[2][0][T+:Q], 2'b0} + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 4'b0} + {L2_out[3][1][T+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][T+:Q], 2'b0} + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 4'b0} + {L2_out[3][3][T+:Q], 2'b0}, 4'b0};

                          out_tmp[PM4+:PQ4] = {{L2_out[0][0][M+:Q], 2'b0} + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 4'b0} + {L2_out[1][1][M+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][M+:Q], 2'b0} + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 4'b0} + {L2_out[1][3][M+:Q], 2'b0}}
                                    + {{L2_out[2][0][M+:Q], 2'b0} + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 4'b0} + {L2_out[3][1][M+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][M+:Q], 2'b0} + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 4'b0} + {L2_out[3][3][M+:Q], 2'b0}, 4'b0};

                          out_tmp[PQ4+:PQ4] = {{L2_out[0][0][Q+:Q], 2'b0} + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 4'b0} + {L2_out[1][1][Q+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][Q+:Q], 2'b0} + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 4'b0} + {L2_out[1][3][Q+:Q], 2'b0}}
                                    + {{L2_out[2][0][Q+:Q], 2'b0} + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 4'b0} + {L2_out[3][1][Q+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][Q+:Q], 2'b0} + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 4'b0} + {L2_out[3][3][Q+:Q], 2'b0}, 4'b0};

                          out_tmp[0+:PQ4]   = {{L2_out[0][0][0+:Q], 2'b0} + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 4'b0} + {L2_out[1][1][0+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][0+:Q], 2'b0} + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 4'b0} + {L2_out[1][3][0+:Q], 2'b0}}
                                    + {{L2_out[2][0][0+:Q], 2'b0} + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 4'b0} + {L2_out[3][1][0+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][0+:Q], 2'b0} + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 4'b0} + {L2_out[3][3][0+:Q], 2'b0}, 4'b0};
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp[PZ2+:PQ2] = {{L2_out[0][0][T+:Q], 2'b0} + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 4'b0} + {L2_out[1][1][T+:Q], 2'b0}}
                                            + {{L2_out[2][0][T+:Q], 2'b0} + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 4'b0} + {L2_out[3][1][T+:Q], 2'b0}, 4'b0};
                          out_tmp[PT4+:PQ2] = {{L2_out[0][2][T+:Q], 2'b0} + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 4'b0} + {L2_out[1][3][T+:Q], 2'b0}}      
                                            + {{L2_out[2][2][T+:Q], 2'b0} + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 4'b0} + {L2_out[3][3][T+:Q], 2'b0}, 4'b0};

                          out_tmp[PT2+:PQ2] = {{L2_out[0][0][M+:Q], 2'b0} + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 4'b0} + {L2_out[1][1][M+:Q], 2'b0}}
                                    + {{L2_out[2][0][M+:Q], 2'b0} + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 4'b0} + {L2_out[3][1][M+:Q], 2'b0}, 4'b0};
                          out_tmp[PM4+:PQ2] = {{L2_out[0][2][M+:Q], 2'b0} + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 4'b0} + {L2_out[1][3][M+:Q], 2'b0}}
                                    + {{L2_out[2][2][M+:Q], 2'b0} + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 4'b0} + {L2_out[3][3][M+:Q], 2'b0}, 4'b0};

                          out_tmp[PM2+:PQ2] = {{L2_out[0][0][Q+:Q], 2'b0} + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 4'b0} + {L2_out[1][1][Q+:Q], 2'b0}}
                                    + {{L2_out[2][0][Q+:Q], 2'b0} + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 4'b0} + {L2_out[3][1][Q+:Q], 2'b0}, 4'b0};
                          out_tmp[PQ4+:PQ2] = {{L2_out[0][2][Q+:Q], 2'b0} + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 4'b0} + {L2_out[1][3][Q+:Q], 2'b0}}
                                    + {{L2_out[2][2][Q+:Q], 2'b0} + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 4'b0} + {L2_out[3][3][Q+:Q], 2'b0}, 4'b0};

                          out_tmp[PQ2+:PQ2] = {{L2_out[0][0][0+:Q], 2'b0} + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 4'b0} + {L2_out[1][1][0+:Q], 2'b0}}
                                    + {{L2_out[2][0][0+:Q], 2'b0} + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 4'b0} + {L2_out[3][1][0+:Q], 2'b0}, 4'b0};
                          out_tmp[0+:PQ2]   = {{L2_out[0][2][0+:Q], 2'b0} + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 4'b0} + {L2_out[1][3][0+:Q], 2'b0}}
                                    + {{L2_out[2][2][0+:Q], 2'b0} + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 4'b0} + {L2_out[3][3][0+:Q], 2'b0}, 4'b0};
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[PZ3+:PQ1] = L2_out[0][0][T+:Q] + {L2_out[1][0][T+:Q], 2'b0} + {L2_out[2][0][T+:Q] + {L2_out[3][0][T+:Q], 2'b0}, 4'b0};
                          out_tmp[PZ2+:PQ1] = L2_out[0][1][T+:Q] + {L2_out[1][1][T+:Q], 2'b0} + {L2_out[2][1][T+:Q] + {L2_out[3][1][T+:Q], 2'b0}, 4'b0};
                          out_tmp[PZ1+:PQ1] = L2_out[0][2][T+:Q] + {L2_out[1][2][T+:Q], 2'b0} + {L2_out[2][2][T+:Q] + {L2_out[3][2][T+:Q], 2'b0}, 4'b0};
                          out_tmp[PT4+:PQ1] = L2_out[0][3][T+:Q] + {L2_out[1][3][T+:Q], 2'b0} + {L2_out[2][3][T+:Q] + {L2_out[3][3][T+:Q], 2'b0}, 4'b0};
                                                                              
                          out_tmp[PT3+:PQ1] = L2_out[0][0][M+:Q] + {L2_out[1][0][M+:Q], 2'b0} + {L2_out[2][0][M+:Q] + {L2_out[3][0][M+:Q], 2'b0}, 4'b0};
                          out_tmp[PT2+:PQ1] = L2_out[0][1][M+:Q] + {L2_out[1][1][M+:Q], 2'b0} + {L2_out[2][1][M+:Q] + {L2_out[3][1][M+:Q], 2'b0}, 4'b0};
                          out_tmp[PT1+:PQ1] = L2_out[0][2][M+:Q] + {L2_out[1][2][M+:Q], 2'b0} + {L2_out[2][2][M+:Q] + {L2_out[3][2][M+:Q], 2'b0}, 4'b0};
                          out_tmp[PM4+:PQ1] = L2_out[0][3][M+:Q] + {L2_out[1][3][M+:Q], 2'b0} + {L2_out[2][3][M+:Q] + {L2_out[3][3][M+:Q], 2'b0}, 4'b0};
                                                                              
                          out_tmp[PM3+:PQ1] = L2_out[0][0][Q+:Q] + {L2_out[1][0][Q+:Q], 2'b0} + {L2_out[2][0][Q+:Q] + {L2_out[3][0][Q+:Q], 2'b0}, 4'b0};
                          out_tmp[PM2+:PQ1] = L2_out[0][1][Q+:Q] + {L2_out[1][1][Q+:Q], 2'b0} + {L2_out[2][1][Q+:Q] + {L2_out[3][1][Q+:Q], 2'b0}, 4'b0};
                          out_tmp[PM1+:PQ1] = L2_out[0][2][Q+:Q] + {L2_out[1][2][Q+:Q], 2'b0} + {L2_out[2][2][Q+:Q] + {L2_out[3][2][Q+:Q], 2'b0}, 4'b0};
                          out_tmp[PQ4+:PQ1] = L2_out[0][3][Q+:Q] + {L2_out[1][3][Q+:Q], 2'b0} + {L2_out[2][3][Q+:Q] + {L2_out[3][3][Q+:Q], 2'b0}, 4'b0};
                                                                              
                          out_tmp[PQ3+:PQ1] = L2_out[0][0][0+:Q] + {L2_out[1][0][0+:Q], 2'b0} + {L2_out[2][0][0+:Q] + {L2_out[3][0][0+:Q], 2'b0}, 4'b0};
                          out_tmp[PQ2+:PQ1] = L2_out[0][1][0+:Q] + {L2_out[1][1][0+:Q], 2'b0} + {L2_out[2][1][0+:Q] + {L2_out[3][1][0+:Q], 2'b0}, 4'b0};
                          out_tmp[PQ1+:PQ1] = L2_out[0][2][0+:Q] + {L2_out[1][2][0+:Q], 2'b0} + {L2_out[2][2][0+:Q] + {L2_out[3][2][0+:Q], 2'b0}, 4'b0};
                          out_tmp[0+:PQ1]   = L2_out[0][3][0+:Q] + {L2_out[1][3][0+:Q], 2'b0} + {L2_out[2][3][0+:Q] + {L2_out[3][3][0+:Q], 2'b0}, 4'b0};
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[PZ3+:PQ1] = {L2_out[0][0][T+:Q], 2'b0} + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 4'b0} + {L2_out[1][1][T+:Q], 2'b0};
                          out_tmp[PZ2+:PQ1] = {L2_out[0][2][T+:Q], 2'b0} + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 4'b0} + {L2_out[1][3][T+:Q], 2'b0};
                          out_tmp[PZ1+:PQ1] = {L2_out[2][0][T+:Q], 2'b0} + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 4'b0} + {L2_out[3][1][T+:Q], 2'b0};
                          out_tmp[PT4+:PQ1] = {L2_out[2][2][T+:Q], 2'b0} + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 4'b0} + {L2_out[3][3][T+:Q], 2'b0};
                                                                                              
                          out_tmp[PT3+:PQ1] = {L2_out[0][0][M+:Q], 2'b0} + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 4'b0} + {L2_out[1][1][M+:Q], 2'b0};
                          out_tmp[PT2+:PQ1] = {L2_out[0][2][M+:Q], 2'b0} + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 4'b0} + {L2_out[1][3][M+:Q], 2'b0};
                          out_tmp[PT1+:PQ1] = {L2_out[2][0][M+:Q], 2'b0} + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 4'b0} + {L2_out[3][1][M+:Q], 2'b0};
                          out_tmp[PM4+:PQ1] = {L2_out[2][2][M+:Q], 2'b0} + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 4'b0} + {L2_out[3][3][M+:Q], 2'b0};
                                                                                              
                          out_tmp[PM3+:PQ1] = {L2_out[0][0][Q+:Q], 2'b0} + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 4'b0} + {L2_out[1][1][Q+:Q], 2'b0};
                          out_tmp[PM2+:PQ1] = {L2_out[0][2][Q+:Q], 2'b0} + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 4'b0} + {L2_out[1][3][Q+:Q], 2'b0};
                          out_tmp[PM1+:PQ1] = {L2_out[2][0][Q+:Q], 2'b0} + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 4'b0} + {L2_out[3][1][Q+:Q], 2'b0};
                          out_tmp[PQ4+:PQ1] = {L2_out[2][2][Q+:Q], 2'b0} + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 4'b0} + {L2_out[3][3][Q+:Q], 2'b0};
                                                                                              
                          out_tmp[PQ3+:PQ1] = {L2_out[0][0][0+:Q], 2'b0} + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 4'b0} + {L2_out[1][1][0+:Q], 2'b0};
                          out_tmp[PQ2+:PQ1] = {L2_out[0][2][0+:Q], 2'b0} + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 4'b0} + {L2_out[1][3][0+:Q], 2'b0};
                          out_tmp[PQ1+:PQ1] = {L2_out[2][0][0+:Q], 2'b0} + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 4'b0} + {L2_out[3][1][0+:Q], 2'b0};
                          out_tmp[0+:PQ1]   = {L2_out[2][2][0+:Q], 2'b0} + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 4'b0} + {L2_out[3][3][0+:Q], 2'b0};
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp = {L2_out[0][0], L2_out[0][1], L2_out[0][2], L2_out[0][3], 
                                 L2_out[1][0], L2_out[1][1], L2_out[1][2], L2_out[1][3],
                                 L2_out[2][0], L2_out[2][1], L2_out[2][2], L2_out[2][3],
                                 L2_out[3][0], L2_out[3][1], L2_out[3][2], L2_out[3][3]};
                        end
                      endcase
                    end
                  end
                  4'b1111: begin: L2_OUT_OUT  // L2_out = 1x8-bits = 24-bits
                    // L2 produces 1 output - instead of 16 add/shift trees, we only need 1
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = {{L2_out[0][0], 2'b0} + L2_out[0][1] + {L2_out[1][0], 4'b0} + {L2_out[1][1], 2'b0}, 4'b0}
                              + {{L2_out[0][2], 2'b0} + L2_out[0][3] + {L2_out[1][2], 4'b0} + {L2_out[1][3], 2'b0}}
                              + {{L2_out[2][0], 2'b0} + L2_out[2][1] + {L2_out[3][0], 4'b0} + {L2_out[3][1], 2'b0}, 8'b0}
                              + {{L2_out[2][2], 2'b0} + L2_out[2][3] + {L2_out[3][2], 4'b0} + {L2_out[3][3], 2'b0}, 4'b0};
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp[PM4+:PM4] = {{L2_out[0][0], 2'b0} + L2_out[0][1] + {L2_out[1][0], 4'b0} + {L2_out[1][1], 2'b0}}
                                    + {{L2_out[2][0], 2'b0} + L2_out[2][1] + {L2_out[3][0], 4'b0} + {L2_out[3][1], 2'b0}, 4'b0};

                          out_tmp[0+:PM4]   = {{L2_out[0][2], 2'b0} + L2_out[0][3] + {L2_out[1][2], 4'b0} + {L2_out[1][3], 2'b0}}
                                    + {{L2_out[2][2], 2'b0} + L2_out[2][3] + {L2_out[3][2], 4'b0} + {L2_out[3][3], 2'b0}, 4'b0};
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[PT4+:PQ4] = L2_out[0][0] + {L2_out[1][0], 2'b0} + {L2_out[2][0] + {L2_out[3][0], 2'b0}, 4'b0};
                          out_tmp[PM4+:PQ4] = L2_out[0][1] + {L2_out[1][1], 2'b0} + {L2_out[2][1] + {L2_out[3][1], 2'b0}, 4'b0};
                          out_tmp[PQ4+:PQ4] = L2_out[0][2] + {L2_out[1][2], 2'b0} + {L2_out[2][2] + {L2_out[3][2], 2'b0}, 4'b0};
                          out_tmp[0+:PQ4]   = L2_out[0][3] + {L2_out[1][3], 2'b0} + {L2_out[2][3] + {L2_out[3][3], 2'b0}, 4'b0};
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[PT4+:PQ4] = {L2_out[0][0], 2'b0} + L2_out[0][1] + {L2_out[1][0], 4'b0} + {L2_out[1][1], 2'b0};
                          out_tmp[PM4+:PQ4] = {L2_out[2][0], 2'b0} + L2_out[2][1] + {L2_out[3][0], 4'b0} + {L2_out[3][1], 2'b0};
                          out_tmp[PQ4+:PQ4] = {L2_out[0][2], 2'b0} + L2_out[0][3] + {L2_out[1][2], 4'b0} + {L2_out[1][3], 2'b0};
                          out_tmp[0+:PQ4]   = {L2_out[2][2], 2'b0} + L2_out[2][3] + {L2_out[3][2], 4'b0} + {L2_out[3][3], 2'b0};
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp = {L2_out[0][0], L2_out[0][1], L2_out[0][2], L2_out[0][3], 
                                 L2_out[1][0], L2_out[1][1], L2_out[1][2], L2_out[1][3],
                                 L2_out[2][0], L2_out[2][1], L2_out[2][2], L2_out[2][3],
                                 L2_out[3][0], L2_out[3][1], L2_out[3][2], L2_out[3][3]};
                        end
                      endcase
                    end
                  end
                endcase
              end
              2'b10: begin: L3_OUT_IN
                always_comb begin
                  L2_w = '{'{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                       '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                       '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                       '{w[3][0], w[2][0], w[1][0], w[0][0]}};
                  
                  L2_a = '{'{a[0][0], a[0][prec[0]?2:0], a[0][prec[1]], a[0][prec[0]?3:prec[1]]}, 
                       '{a[1][0], a[1][prec[0]?2:0], a[1][prec[1]], a[1][prec[0]?3:prec[1]]}, 
                       '{a[2][0], a[2][prec[0]?2:0], a[2][prec[1]], a[2][prec[0]?3:prec[1]]}, 
                       '{a[3][0], a[3][prec[0]?2:0], a[3][prec[1]], a[3][prec[0]?3:prec[1]]}};
                end
                case(L2_MODE)
                  4'b0000: begin: L2_IN_IN
                    // NOTE: Same as BG_L2 - Redundant! 
                    // BG_L2: 4x4 L2 units, each having an add/shift tree (total = 16)
                    // BG_L3: Each L2 produces 16 outputs, requiring 16 add/shift trees in L3 (total = 16)
                    // As a result, no savings what so ever 
                  end
                  4'b1010: begin: L2_OUT_IN
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b // NOTE: FIXED! 
                          out_tmp[PT4+:PQ4] = {{L2_out[0][0][T+:Q], 2'b0} + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 4'b0} + {L2_out[1][1][T+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][T+:Q], 2'b0} + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 4'b0} + {L2_out[1][3][T+:Q], 2'b0}}
                                    + {{L2_out[2][0][T+:Q], 2'b0} + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 4'b0} + {L2_out[3][1][T+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][T+:Q], 2'b0} + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 4'b0} + {L2_out[3][3][T+:Q], 2'b0}, 4'b0};

                          out_tmp[PM4+:PQ4] = {{L2_out[0][0][M+:Q], 2'b0} + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 4'b0} + {L2_out[1][1][M+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][M+:Q], 2'b0} + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 4'b0} + {L2_out[1][3][M+:Q], 2'b0}}
                                    + {{L2_out[2][0][M+:Q], 2'b0} + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 4'b0} + {L2_out[3][1][M+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][M+:Q], 2'b0} + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 4'b0} + {L2_out[3][3][M+:Q], 2'b0}, 4'b0};

                          out_tmp[PQ4+:PQ4] = {{L2_out[0][0][Q+:Q], 2'b0} + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 4'b0} + {L2_out[1][1][Q+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][Q+:Q], 2'b0} + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 4'b0} + {L2_out[1][3][Q+:Q], 2'b0}}
                                    + {{L2_out[2][0][Q+:Q], 2'b0} + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 4'b0} + {L2_out[3][1][Q+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][Q+:Q], 2'b0} + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 4'b0} + {L2_out[3][3][Q+:Q], 2'b0}, 4'b0};

                          out_tmp[0+:PQ4]   = {{L2_out[0][0][0+:Q], 2'b0} + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 4'b0} + {L2_out[1][1][0+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][0+:Q], 2'b0} + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 4'b0} + {L2_out[1][3][0+:Q], 2'b0}}
                                    + {{L2_out[2][0][0+:Q], 2'b0} + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 4'b0} + {L2_out[3][1][0+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][0+:Q], 2'b0} + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 4'b0} + {L2_out[3][3][0+:Q], 2'b0}, 4'b0};
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp[PT4+:PQ4] = {{L2_out[0][0][T+:Q], 2'b0} + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 4'b0} + {L2_out[1][1][T+:Q], 2'b0}}
                                    + {{L2_out[0][2][T+:Q], 2'b0} + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 4'b0} + {L2_out[1][3][T+:Q], 2'b0}}
                                    + {{L2_out[2][0][T+:Q], 2'b0} + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 4'b0} + {L2_out[3][1][T+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[2][2][T+:Q], 2'b0} + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 4'b0} + {L2_out[3][3][T+:Q], 2'b0}, 4'b0};

                          out_tmp[PM4+:PQ4] = {{L2_out[0][0][M+:Q], 2'b0} + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 4'b0} + {L2_out[1][1][M+:Q], 2'b0}}
                                    + {{L2_out[0][2][M+:Q], 2'b0} + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 4'b0} + {L2_out[1][3][M+:Q], 2'b0}}
                                    + {{L2_out[2][0][M+:Q], 2'b0} + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 4'b0} + {L2_out[3][1][M+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[2][2][M+:Q], 2'b0} + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 4'b0} + {L2_out[3][3][M+:Q], 2'b0}, 4'b0};

                          out_tmp[PQ4+:PQ4] = {{L2_out[0][0][Q+:Q], 2'b0} + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 4'b0} + {L2_out[1][1][Q+:Q], 2'b0}}
                                    + {{L2_out[0][2][Q+:Q], 2'b0} + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 4'b0} + {L2_out[1][3][Q+:Q], 2'b0}}
                                    + {{L2_out[2][0][Q+:Q], 2'b0} + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 4'b0} + {L2_out[3][1][Q+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[2][2][Q+:Q], 2'b0} + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 4'b0} + {L2_out[3][3][Q+:Q], 2'b0}, 4'b0};

                          out_tmp[0+:PQ4]   = {{L2_out[0][0][0+:Q], 2'b0} + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 4'b0} + {L2_out[1][1][0+:Q], 2'b0}}
                                    + {{L2_out[0][2][0+:Q], 2'b0} + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 4'b0} + {L2_out[1][3][0+:Q], 2'b0}}
                                    + {{L2_out[2][0][0+:Q], 2'b0} + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 4'b0} + {L2_out[3][1][0+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[2][2][0+:Q], 2'b0} + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 4'b0} + {L2_out[3][3][0+:Q], 2'b0}, 4'b0};
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[PT4+:PQ4] = {L2_out[0][0][T+:Q] + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 2'b0} + {L2_out[1][1][T+:Q], 2'b0}}
                                    + {L2_out[0][2][T+:Q] + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 2'b0} + {L2_out[1][3][T+:Q], 2'b0}}
                                    + {L2_out[2][0][T+:Q] + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 2'b0} + {L2_out[3][1][T+:Q], 2'b0}, 4'b0}
                                    + {L2_out[2][2][T+:Q] + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 2'b0} + {L2_out[3][3][T+:Q], 2'b0}, 4'b0};

                          out_tmp[PM4+:PQ4] = {L2_out[0][0][M+:Q] + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 2'b0} + {L2_out[1][1][M+:Q], 2'b0}}
                                    + {L2_out[0][2][M+:Q] + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 2'b0} + {L2_out[1][3][M+:Q], 2'b0}}
                                    + {L2_out[2][0][M+:Q] + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 2'b0} + {L2_out[3][1][M+:Q], 2'b0}, 4'b0}
                                    + {L2_out[2][2][M+:Q] + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 2'b0} + {L2_out[3][3][M+:Q], 2'b0}, 4'b0};

                          out_tmp[PQ4+:PQ4] = {L2_out[0][0][Q+:Q] + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 2'b0} + {L2_out[1][1][Q+:Q], 2'b0}}
                                    + {L2_out[0][2][Q+:Q] + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 2'b0} + {L2_out[1][3][Q+:Q], 2'b0}}
                                    + {L2_out[2][0][Q+:Q] + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 2'b0} + {L2_out[3][1][Q+:Q], 2'b0}, 4'b0}
                                    + {L2_out[2][2][Q+:Q] + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 2'b0} + {L2_out[3][3][Q+:Q], 2'b0}, 4'b0};

                          out_tmp[0+:PQ4]   = {L2_out[0][0][0+:Q] + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 2'b0} + {L2_out[1][1][0+:Q], 2'b0}}
                                    + {L2_out[0][2][0+:Q] + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 2'b0} + {L2_out[1][3][0+:Q], 2'b0}}
                                    + {L2_out[2][0][0+:Q] + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 2'b0} + {L2_out[3][1][0+:Q], 2'b0}, 4'b0}
                                    + {L2_out[2][2][0+:Q] + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 2'b0} + {L2_out[3][3][0+:Q], 2'b0}, 4'b0};
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[PZ2+:PQ2] = {L2_out[0][0][T+:Q], 2'b0} + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 4'b0} + {L2_out[1][1][T+:Q], 2'b0}
                                    + {L2_out[0][2][T+:Q], 2'b0} + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 4'b0} + {L2_out[1][3][T+:Q], 2'b0};
                          out_tmp[PT4+:PQ2] = {L2_out[2][0][T+:Q], 2'b0} + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 4'b0} + {L2_out[3][1][T+:Q], 2'b0}
                                    + {L2_out[2][2][T+:Q], 2'b0} + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 4'b0} + {L2_out[3][3][T+:Q], 2'b0};

                          out_tmp[PT2+:PQ2] = {L2_out[0][0][M+:Q], 2'b0} + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 4'b0} + {L2_out[1][1][M+:Q], 2'b0}
                                    + {L2_out[0][2][M+:Q], 2'b0} + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 4'b0} + {L2_out[1][3][M+:Q], 2'b0};
                          out_tmp[PM4+:PQ2] = {L2_out[2][0][M+:Q], 2'b0} + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 4'b0} + {L2_out[3][1][M+:Q], 2'b0}
                                    + {L2_out[2][2][M+:Q], 2'b0} + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 4'b0} + {L2_out[3][3][M+:Q], 2'b0};

                          out_tmp[PM2+:PQ2] = {L2_out[0][0][Q+:Q], 2'b0} + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 4'b0} + {L2_out[1][1][Q+:Q], 2'b0}
                                    + {L2_out[0][2][Q+:Q], 2'b0} + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 4'b0} + {L2_out[1][3][Q+:Q], 2'b0};
                          out_tmp[PQ4+:PQ2] = {L2_out[2][0][Q+:Q], 2'b0} + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 4'b0} + {L2_out[3][1][Q+:Q], 2'b0}
                                    + {L2_out[2][2][Q+:Q], 2'b0} + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 4'b0} + {L2_out[3][3][Q+:Q], 2'b0};

                          out_tmp[PQ2+:PQ2] = {L2_out[0][0][0+:Q], 2'b0} + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 4'b0} + {L2_out[1][1][0+:Q], 2'b0}
                                    + {L2_out[0][2][0+:Q], 2'b0} + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 4'b0} + {L2_out[1][3][0+:Q], 2'b0};
                          out_tmp[0+:PQ2]   = {L2_out[2][0][0+:Q], 2'b0} + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 4'b0} + {L2_out[3][1][0+:Q], 2'b0}
                                    + {L2_out[2][2][0+:Q], 2'b0} + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 4'b0} + {L2_out[3][3][0+:Q], 2'b0};
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[PZ3+:PQ1] = L2_out[0][0][T+:Q] + L2_out[0][1][T+:Q] + L2_out[0][2][T+:Q] + L2_out[0][3][T+:Q];
                          out_tmp[PZ2+:PQ1] = L2_out[1][0][T+:Q] + L2_out[1][1][T+:Q] + L2_out[1][2][T+:Q] + L2_out[1][3][T+:Q];
                          out_tmp[PZ1+:PQ1] = L2_out[2][0][T+:Q] + L2_out[2][1][T+:Q] + L2_out[2][2][T+:Q] + L2_out[2][3][T+:Q];
                          out_tmp[PT4+:PQ1] = L2_out[3][0][T+:Q] + L2_out[3][1][T+:Q] + L2_out[3][2][T+:Q] + L2_out[3][3][T+:Q];

                          out_tmp[PT3+:PQ1] = L2_out[0][0][M+:Q] + L2_out[0][1][M+:Q] + L2_out[0][2][M+:Q] + L2_out[0][3][M+:Q];
                          out_tmp[PT2+:PQ1] = L2_out[1][0][M+:Q] + L2_out[1][1][M+:Q] + L2_out[1][2][M+:Q] + L2_out[1][3][M+:Q];
                          out_tmp[PT1+:PQ1] = L2_out[2][0][M+:Q] + L2_out[2][1][M+:Q] + L2_out[2][2][M+:Q] + L2_out[2][3][M+:Q];
                          out_tmp[PM4+:PQ1] = L2_out[3][0][M+:Q] + L2_out[3][1][M+:Q] + L2_out[3][2][M+:Q] + L2_out[3][3][M+:Q];

                          out_tmp[PM3+:PQ1] = L2_out[0][0][Q+:Q] + L2_out[0][1][Q+:Q] + L2_out[0][2][Q+:Q] + L2_out[0][3][Q+:Q];
                          out_tmp[PM2+:PQ1] = L2_out[1][0][Q+:Q] + L2_out[1][1][Q+:Q] + L2_out[1][2][Q+:Q] + L2_out[1][3][Q+:Q];
                          out_tmp[PM1+:PQ1] = L2_out[2][0][Q+:Q] + L2_out[2][1][Q+:Q] + L2_out[2][2][Q+:Q] + L2_out[2][3][Q+:Q];
                          out_tmp[PQ4+:PQ1] = L2_out[3][0][Q+:Q] + L2_out[3][1][Q+:Q] + L2_out[3][2][Q+:Q] + L2_out[3][3][Q+:Q];

                          out_tmp[PQ3+:PQ1] = L2_out[0][0][0+:Q] + L2_out[0][1][0+:Q] + L2_out[0][2][0+:Q] + L2_out[0][3][0+:Q];
                          out_tmp[PQ2+:PQ1] = L2_out[1][0][0+:Q] + L2_out[1][1][0+:Q] + L2_out[1][2][0+:Q] + L2_out[1][3][0+:Q];
                          out_tmp[PQ1+:PQ1] = L2_out[2][0][0+:Q] + L2_out[2][1][0+:Q] + L2_out[2][2][0+:Q] + L2_out[2][3][0+:Q];
                          out_tmp[0+:PQ1]   = L2_out[3][0][0+:Q] + L2_out[3][1][0+:Q] + L2_out[3][2][0+:Q] + L2_out[3][3][0+:Q];
                        end
                      endcase
                    end
                  end
                  4'b1111: begin: L2_OUT_OUT  // L2_out = 1x8-bits = 24-bits
                    // L2 produces 1 output - instead of 16 add/shift trees, we only need 1
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = {{L2_out[0][0], 2'b0} + L2_out[0][1] + {L2_out[1][0], 4'b0} + {L2_out[1][1], 2'b0}, 4'b0}
                              + {{L2_out[0][2], 2'b0} + L2_out[0][3] + {L2_out[1][2], 4'b0} + {L2_out[1][3], 2'b0}}
                              + {{L2_out[2][0], 2'b0} + L2_out[2][1] + {L2_out[3][0], 4'b0} + {L2_out[3][1], 2'b0}, 8'b0}
                              + {{L2_out[2][2], 2'b0} + L2_out[2][3] + {L2_out[3][2], 4'b0} + {L2_out[3][3], 2'b0}, 4'b0};
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp = {{L2_out[0][0], 2'b0} + L2_out[0][1] + {L2_out[1][0], 4'b0} + {L2_out[1][1], 2'b0}}
                              + {{L2_out[2][0], 2'b0} + L2_out[2][1] + {L2_out[3][0], 4'b0} + {L2_out[3][1], 2'b0}, 4'b0}
                              + {{L2_out[0][2], 2'b0} + L2_out[0][3] + {L2_out[1][2], 4'b0} + {L2_out[1][3], 2'b0}}
                              + {{L2_out[2][2], 2'b0} + L2_out[2][3] + {L2_out[3][2], 4'b0} + {L2_out[3][3], 2'b0}, 4'b0};
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp = L2_out[0][0] + {L2_out[1][0], 2'b0} + {L2_out[2][0] + {L2_out[3][0], 2'b0}, 4'b0}
                              + L2_out[0][1] + {L2_out[1][1], 2'b0} + {L2_out[2][1] + {L2_out[3][1], 2'b0}, 4'b0}
                              + L2_out[0][2] + {L2_out[1][2], 2'b0} + {L2_out[2][2] + {L2_out[3][2], 2'b0}, 4'b0}
                              + L2_out[0][3] + {L2_out[1][3], 2'b0} + {L2_out[2][3] + {L2_out[3][3], 2'b0}, 4'b0};
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[PM4+:PM4] = {L2_out[0][0], 2'b0} + L2_out[0][1] + {L2_out[1][0], 4'b0} + {L2_out[1][1], 2'b0}
                                    + {L2_out[0][2], 2'b0} + L2_out[0][3] + {L2_out[1][2], 4'b0} + {L2_out[1][3], 2'b0};
                          out_tmp[0+:PM4]   = {L2_out[2][0], 2'b0} + L2_out[2][1] + {L2_out[3][0], 4'b0} + {L2_out[3][1], 2'b0}
                                    + {L2_out[2][2], 2'b0} + L2_out[2][3] + {L2_out[3][2], 4'b0} + {L2_out[3][3], 2'b0};
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[PT4+:PQ4] = L2_out[0][0] + L2_out[0][1] + L2_out[0][2] + L2_out[0][3];
                          out_tmp[PM4+:PQ4] = L2_out[1][0] + L2_out[1][1] + L2_out[1][2] + L2_out[1][3];
                          out_tmp[PQ4+:PQ4] = L2_out[2][0] + L2_out[2][1] + L2_out[2][2] + L2_out[2][3];
                          out_tmp[0+:PQ4]   = L2_out[3][0] + L2_out[3][1] + L2_out[3][2] + L2_out[3][3];
                        end
                      endcase
                    end
                  end
                endcase
              end
              2'b11: begin: L3_OUT_OUT
                always_comb begin
                  L2_w = '{'{w[3][0],                 w[2][0],                 w[1][0],                 w[0][0]}, 
                           '{w[3][prec[2]?2:0],       w[2][prec[2]?2:0],       w[1][prec[2]?2:0],       w[0][prec[2]?2:0]}, 
                           '{w[3][prec[3]],           w[2][prec[3]],           w[1][prec[3]],           w[0][prec[3]]}, 
                           '{w[3][prec[2]?3:prec[3]], w[2][prec[2]?3:prec[3]], w[1][prec[2]?3:prec[3]], w[0][prec[2]?3:prec[3]]}};
                  
                  L2_a = '{'{a[0][0], a[0][prec[0]?2:0], a[0][prec[1]], a[0][prec[0]?3:prec[1]]}, 
                           '{a[1][0], a[1][prec[0]?2:0], a[1][prec[1]], a[1][prec[0]?3:prec[1]]}, 
                           '{a[2][0], a[2][prec[0]?2:0], a[2][prec[1]], a[2][prec[0]?3:prec[1]]}, 
                           '{a[3][0], a[3][prec[0]?2:0], a[3][prec[1]], a[3][prec[0]?3:prec[1]]}};
                end
                case(L2_MODE)
                  4'b0000: begin: L2_IN_IN
                    // NOTE: Same as BG_L2 - Redundant! 
                    // BG_L2: 4x4 L2 units, each having an add/shift tree (total = 16)
                    // BG_L3: Each L2 produces 16 outputs, requiring 16 add/shift trees in L3 (total = 16)
                    // As a result, no savings what so ever 
                  end
                  4'b1010: begin: L2_OUT_IN   // L2_out = 4*6-bits = 24-bits
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp[PT4+:PQ4] = {{L2_out[0][0][T+:Q], 2'b0} + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 4'b0} + {L2_out[1][1][T+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][T+:Q], 2'b0} + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 4'b0} + {L2_out[1][3][T+:Q], 2'b0}}
                                    + {{L2_out[2][0][T+:Q], 2'b0} + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 4'b0} + {L2_out[3][1][T+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][T+:Q], 2'b0} + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 4'b0} + {L2_out[3][3][T+:Q], 2'b0}, 4'b0};

                          out_tmp[PM4+:PQ4] = {{L2_out[0][0][M+:Q], 2'b0} + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 4'b0} + {L2_out[1][1][M+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][M+:Q], 2'b0} + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 4'b0} + {L2_out[1][3][M+:Q], 2'b0}}
                                    + {{L2_out[2][0][M+:Q], 2'b0} + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 4'b0} + {L2_out[3][1][M+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][M+:Q], 2'b0} + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 4'b0} + {L2_out[3][3][M+:Q], 2'b0}, 4'b0};

                          out_tmp[PQ4+:PQ4] = {{L2_out[0][0][Q+:Q], 2'b0} + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 4'b0} + {L2_out[1][1][Q+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][Q+:Q], 2'b0} + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 4'b0} + {L2_out[1][3][Q+:Q], 2'b0}}
                                    + {{L2_out[2][0][Q+:Q], 2'b0} + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 4'b0} + {L2_out[3][1][Q+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][Q+:Q], 2'b0} + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 4'b0} + {L2_out[3][3][Q+:Q], 2'b0}, 4'b0};

                          out_tmp[0+:PQ4]   = {{L2_out[0][0][0+:Q], 2'b0} + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 4'b0} + {L2_out[1][1][0+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[0][2][0+:Q], 2'b0} + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 4'b0} + {L2_out[1][3][0+:Q], 2'b0}}
                                    + {{L2_out[2][0][0+:Q], 2'b0} + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 4'b0} + {L2_out[3][1][0+:Q], 2'b0}, 8'b0}
                                    + {{L2_out[2][2][0+:Q], 2'b0} + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 4'b0} + {L2_out[3][3][0+:Q], 2'b0}, 4'b0};
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp[PT4+:PQ4] = {{L2_out[0][0][T+:Q], 2'b0} + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 4'b0} + {L2_out[1][1][T+:Q], 2'b0}}
                                    + {{L2_out[0][2][T+:Q], 2'b0} + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 4'b0} + {L2_out[1][3][T+:Q], 2'b0}}
                                    + {{L2_out[2][0][T+:Q], 2'b0} + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 4'b0} + {L2_out[3][1][T+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[2][2][T+:Q], 2'b0} + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 4'b0} + {L2_out[3][3][T+:Q], 2'b0}, 4'b0};

                          out_tmp[PM4+:PQ4] = {{L2_out[0][0][M+:Q], 2'b0} + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 4'b0} + {L2_out[1][1][M+:Q], 2'b0}}
                                    + {{L2_out[0][2][M+:Q], 2'b0} + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 4'b0} + {L2_out[1][3][M+:Q], 2'b0}}
                                    + {{L2_out[2][0][M+:Q], 2'b0} + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 4'b0} + {L2_out[3][1][M+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[2][2][M+:Q], 2'b0} + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 4'b0} + {L2_out[3][3][M+:Q], 2'b0}, 4'b0};

                          out_tmp[PQ4+:PQ4] = {{L2_out[0][0][Q+:Q], 2'b0} + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 4'b0} + {L2_out[1][1][Q+:Q], 2'b0}}
                                    + {{L2_out[0][2][Q+:Q], 2'b0} + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 4'b0} + {L2_out[1][3][Q+:Q], 2'b0}}
                                    + {{L2_out[2][0][Q+:Q], 2'b0} + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 4'b0} + {L2_out[3][1][Q+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[2][2][Q+:Q], 2'b0} + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 4'b0} + {L2_out[3][3][Q+:Q], 2'b0}, 4'b0};

                          out_tmp[0+:PQ4]   = {{L2_out[0][0][0+:Q], 2'b0} + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 4'b0} + {L2_out[1][1][0+:Q], 2'b0}}
                                    + {{L2_out[0][2][0+:Q], 2'b0} + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 4'b0} + {L2_out[1][3][0+:Q], 2'b0}}
                                    + {{L2_out[2][0][0+:Q], 2'b0} + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 4'b0} + {L2_out[3][1][0+:Q], 2'b0}, 4'b0}
                                    + {{L2_out[2][2][0+:Q], 2'b0} + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 4'b0} + {L2_out[3][3][0+:Q], 2'b0}, 4'b0};
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[PT4+:PQ4] = {L2_out[0][0][T+:Q] + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 2'b0} + {L2_out[1][1][T+:Q], 2'b0}}
                                    + {L2_out[0][2][T+:Q] + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 2'b0} + {L2_out[1][3][T+:Q], 2'b0}}
                                    + {L2_out[2][0][T+:Q] + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 2'b0} + {L2_out[3][1][T+:Q], 2'b0}, 4'b0}
                                    + {L2_out[2][2][T+:Q] + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 2'b0} + {L2_out[3][3][T+:Q], 2'b0}, 4'b0};

                          out_tmp[PM4+:PQ4] = {L2_out[0][0][M+:Q] + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 2'b0} + {L2_out[1][1][M+:Q], 2'b0}}
                                    + {L2_out[0][2][M+:Q] + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 2'b0} + {L2_out[1][3][M+:Q], 2'b0}}
                                    + {L2_out[2][0][M+:Q] + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 2'b0} + {L2_out[3][1][M+:Q], 2'b0}, 4'b0}
                                    + {L2_out[2][2][M+:Q] + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 2'b0} + {L2_out[3][3][M+:Q], 2'b0}, 4'b0};

                          out_tmp[PQ4+:PQ4] = {L2_out[0][0][Q+:Q] + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 2'b0} + {L2_out[1][1][Q+:Q], 2'b0}}
                                    + {L2_out[0][2][Q+:Q] + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 2'b0} + {L2_out[1][3][Q+:Q], 2'b0}}
                                    + {L2_out[2][0][Q+:Q] + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 2'b0} + {L2_out[3][1][Q+:Q], 2'b0}, 4'b0}
                                    + {L2_out[2][2][Q+:Q] + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 2'b0} + {L2_out[3][3][Q+:Q], 2'b0}, 4'b0};

                          out_tmp[0+:PQ4]   = {L2_out[0][0][0+:Q] + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 2'b0} + {L2_out[1][1][0+:Q], 2'b0}}
                                    + {L2_out[0][2][0+:Q] + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 2'b0} + {L2_out[1][3][0+:Q], 2'b0}}
                                    + {L2_out[2][0][0+:Q] + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 2'b0} + {L2_out[3][1][0+:Q], 2'b0}, 4'b0}
                                    + {L2_out[2][2][0+:Q] + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 2'b0} + {L2_out[3][3][0+:Q], 2'b0}, 4'b0};
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[PT4+:PQ4] = {L2_out[0][0][T+:Q], 2'b0} + L2_out[0][1][T+:Q] + {L2_out[1][0][T+:Q], 4'b0} + {L2_out[1][1][T+:Q], 2'b0}
                                    + {L2_out[0][2][T+:Q], 2'b0} + L2_out[0][3][T+:Q] + {L2_out[1][2][T+:Q], 4'b0} + {L2_out[1][3][T+:Q], 2'b0}
                                    + {L2_out[2][0][T+:Q], 2'b0} + L2_out[2][1][T+:Q] + {L2_out[3][0][T+:Q], 4'b0} + {L2_out[3][1][T+:Q], 2'b0}
                                    + {L2_out[2][2][T+:Q], 2'b0} + L2_out[2][3][T+:Q] + {L2_out[3][2][T+:Q], 4'b0} + {L2_out[3][3][T+:Q], 2'b0};

                          out_tmp[PM4+:PQ4] = {L2_out[0][0][M+:Q], 2'b0} + L2_out[0][1][M+:Q] + {L2_out[1][0][M+:Q], 4'b0} + {L2_out[1][1][M+:Q], 2'b0}
                                    + {L2_out[0][2][M+:Q], 2'b0} + L2_out[0][3][M+:Q] + {L2_out[1][2][M+:Q], 4'b0} + {L2_out[1][3][M+:Q], 2'b0}
                                    + {L2_out[2][0][M+:Q], 2'b0} + L2_out[2][1][M+:Q] + {L2_out[3][0][M+:Q], 4'b0} + {L2_out[3][1][M+:Q], 2'b0}
                                    + {L2_out[2][2][M+:Q], 2'b0} + L2_out[2][3][M+:Q] + {L2_out[3][2][M+:Q], 4'b0} + {L2_out[3][3][M+:Q], 2'b0};

                          out_tmp[PQ4+:PQ4] = {L2_out[0][0][Q+:Q], 2'b0} + L2_out[0][1][Q+:Q] + {L2_out[1][0][Q+:Q], 4'b0} + {L2_out[1][1][Q+:Q], 2'b0}
                                    + {L2_out[0][2][Q+:Q], 2'b0} + L2_out[0][3][Q+:Q] + {L2_out[1][2][Q+:Q], 4'b0} + {L2_out[1][3][Q+:Q], 2'b0}
                                    + {L2_out[2][0][Q+:Q], 2'b0} + L2_out[2][1][Q+:Q] + {L2_out[3][0][Q+:Q], 4'b0} + {L2_out[3][1][Q+:Q], 2'b0}
                                    + {L2_out[2][2][Q+:Q], 2'b0} + L2_out[2][3][Q+:Q] + {L2_out[3][2][Q+:Q], 4'b0} + {L2_out[3][3][Q+:Q], 2'b0};

                          out_tmp[0+:PQ4]   = {L2_out[0][0][0+:Q], 2'b0} + L2_out[0][1][0+:Q] + {L2_out[1][0][0+:Q], 4'b0} + {L2_out[1][1][0+:Q], 2'b0}
                                    + {L2_out[0][2][0+:Q], 2'b0} + L2_out[0][3][0+:Q] + {L2_out[1][2][0+:Q], 4'b0} + {L2_out[1][3][0+:Q], 2'b0}
                                    + {L2_out[2][0][0+:Q], 2'b0} + L2_out[2][1][0+:Q] + {L2_out[3][0][0+:Q], 4'b0} + {L2_out[3][1][0+:Q], 2'b0}
                                    + {L2_out[2][2][0+:Q], 2'b0} + L2_out[2][3][0+:Q] + {L2_out[3][2][0+:Q], 4'b0} + {L2_out[3][3][0+:Q], 2'b0};
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[PT4+:PQ4] = L2_out[0][0][T+:Q] + L2_out[0][1][T+:Q] + L2_out[0][2][T+:Q] + L2_out[0][3][T+:Q]
                                    + L2_out[1][0][T+:Q] + L2_out[1][1][T+:Q] + L2_out[1][2][T+:Q] + L2_out[1][3][T+:Q]
                                    + L2_out[2][0][T+:Q] + L2_out[2][1][T+:Q] + L2_out[2][2][T+:Q] + L2_out[2][3][T+:Q]
                                    + L2_out[3][0][T+:Q] + L2_out[3][1][T+:Q] + L2_out[3][2][T+:Q] + L2_out[3][3][T+:Q];

                          out_tmp[PM4+:PQ4] = L2_out[0][0][M+:Q] + L2_out[0][1][M+:Q] + L2_out[0][2][M+:Q] + L2_out[0][3][M+:Q]
                                    + L2_out[1][0][M+:Q] + L2_out[1][1][M+:Q] + L2_out[1][2][M+:Q] + L2_out[1][3][M+:Q]
                                    + L2_out[2][0][M+:Q] + L2_out[2][1][M+:Q] + L2_out[2][2][M+:Q] + L2_out[2][3][M+:Q]
                                    + L2_out[3][0][M+:Q] + L2_out[3][1][M+:Q] + L2_out[3][2][M+:Q] + L2_out[3][3][M+:Q];

                          out_tmp[PQ4+:PQ4] = L2_out[0][0][Q+:Q] + L2_out[0][1][Q+:Q] + L2_out[0][2][Q+:Q] + L2_out[0][3][Q+:Q]
                                    + L2_out[1][0][Q+:Q] + L2_out[1][1][Q+:Q] + L2_out[1][2][Q+:Q] + L2_out[1][3][Q+:Q]
                                    + L2_out[2][0][Q+:Q] + L2_out[2][1][Q+:Q] + L2_out[2][2][Q+:Q] + L2_out[2][3][Q+:Q]
                                    + L2_out[3][0][Q+:Q] + L2_out[3][1][Q+:Q] + L2_out[3][2][Q+:Q] + L2_out[3][3][Q+:Q];

                          out_tmp[0+:PQ4]   = L2_out[0][0][0+:Q] + L2_out[0][1][0+:Q] + L2_out[0][2][0+:Q] + L2_out[0][3][0+:Q]
                                    + L2_out[1][0][0+:Q] + L2_out[1][1][0+:Q] + L2_out[1][2][0+:Q] + L2_out[1][3][0+:Q]
                                    + L2_out[2][0][0+:Q] + L2_out[2][1][0+:Q] + L2_out[2][2][0+:Q] + L2_out[2][3][0+:Q]
                                    + L2_out[3][0][0+:Q] + L2_out[3][1][0+:Q] + L2_out[3][2][0+:Q] + L2_out[3][3][0+:Q];
                        end
                      endcase
                    end
                  end
                  4'b1111: begin: L2_OUT_OUT
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = {{L2_out[0][0], 2'b0} + L2_out[0][1] + {L2_out[1][0], 4'b0} + {L2_out[1][1], 2'b0}, 4'b0}
                              + {{L2_out[0][2], 2'b0} + L2_out[0][3] + {L2_out[1][2], 4'b0} + {L2_out[1][3], 2'b0}}
                              + {{L2_out[2][0], 2'b0} + L2_out[2][1] + {L2_out[3][0], 4'b0} + {L2_out[3][1], 2'b0}, 8'b0}
                              + {{L2_out[2][2], 2'b0} + L2_out[2][3] + {L2_out[3][2], 4'b0} + {L2_out[3][3], 2'b0}, 4'b0};
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp = {{L2_out[0][0], 2'b0} + L2_out[0][1] + {L2_out[1][0], 4'b0} + {L2_out[1][1], 2'b0}}
                              + {{L2_out[0][2], 2'b0} + L2_out[0][3] + {L2_out[1][2], 4'b0} + {L2_out[1][3], 2'b0}}
                              + {{L2_out[2][0], 2'b0} + L2_out[2][1] + {L2_out[3][0], 4'b0} + {L2_out[3][1], 2'b0}, 4'b0}
                              + {{L2_out[2][2], 2'b0} + L2_out[2][3] + {L2_out[3][2], 4'b0} + {L2_out[3][3], 2'b0}, 4'b0};
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp = {L2_out[0][0] + L2_out[0][1] + {L2_out[1][0], 2'b0} + {L2_out[1][1], 2'b0}}
                              + {L2_out[0][2] + L2_out[0][3] + {L2_out[1][2], 2'b0} + {L2_out[1][3], 2'b0}}
                              + {L2_out[2][0] + L2_out[2][1] + {L2_out[3][0], 2'b0} + {L2_out[3][1], 2'b0}, 4'b0}
                              + {L2_out[2][2] + L2_out[2][3] + {L2_out[3][2], 2'b0} + {L2_out[3][3], 2'b0}, 4'b0};
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp = {{L2_out[0][0], 2'b0} + L2_out[0][1] + {L2_out[1][0], 4'b0} + {L2_out[1][1], 2'b0}}
                              + {{L2_out[0][2], 2'b0} + L2_out[0][3] + {L2_out[1][2], 4'b0} + {L2_out[1][3], 2'b0}}
                              + {{L2_out[2][0], 2'b0} + L2_out[2][1] + {L2_out[3][0], 4'b0} + {L2_out[3][1], 2'b0}}
                              + {{L2_out[2][2], 2'b0} + L2_out[2][3] + {L2_out[3][2], 4'b0} + {L2_out[3][3], 2'b0}};
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp = L2_out[0][0] + L2_out[0][1] + L2_out[1][0] + L2_out[1][1]
                              + L2_out[0][2] + L2_out[0][3] + L2_out[1][2] + L2_out[1][3]
                              + L2_out[2][0] + L2_out[2][1] + L2_out[3][0] + L2_out[3][1]
                              + L2_out[2][2] + L2_out[2][3] + L2_out[3][2] + L2_out[3][3]; 
                        end
                      endcase
                    end
                  end
                endcase
              end
            endcase
          end
        endcase
      end

      // TODO: Add Bit_Serial support in DVAFS as well! 
      1'b1: begin: DVAFS_ON
        case(BG)
          2'b00: begin: BG_L2
            case(L3_MODE)
              2'b00: begin: L3_IN_IN
                // Always concatenate outputs from L2 in this case 
                // Always broadcast inputs, regardless of L2_mode
                // Don't need another case statement! 
                always_comb begin
                  // Each one of w[x][y] and a[x][y] are a collection of L2_inputs
                  // w[x][y] and a[x][y] are always broadcast on L3 level 
                  L2_w = '{'{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}};
                  
                  L2_a = '{'{a[0][0], a[0][0], a[0][0], a[0][0]}, 
                           '{a[1][0], a[1][0], a[1][0], a[1][0]}, 
                           '{a[2][0], a[2][0], a[2][0], a[2][0]}, 
                           '{a[3][0], a[3][0], a[3][0], a[3][0]}};

                  out_tmp = {L2_out[0][0], L2_out[0][1], L2_out[0][2], L2_out[0][3], 
                             L2_out[1][0], L2_out[1][1], L2_out[1][2], L2_out[1][3],
                             L2_out[2][0], L2_out[2][1], L2_out[2][2], L2_out[2][3],
                             L2_out[3][0], L2_out[3][1], L2_out[3][2], L2_out[3][3]};
                end
              end
              2'b10: begin: L3_OUT_IN
                // In this mode, different precisions affect the outputs
                // No shifters added here, just different adder logic 
                always_comb begin
                  L2_w = '{'{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][0], w[2][0], w[1][0], w[0][0]}};
                  
                  L2_a = '{'{a[0][0], a[0][2], a[0][1], a[0][3]}, 
                           '{a[1][0], a[1][2], a[1][1], a[1][3]}, 
                           '{a[2][0], a[2][2], a[2][1], a[2][3]}, 
                           '{a[3][0], a[3][2], a[3][1], a[3][3]}};
                end
                case(L2_MODE)
                  4'b0000: begin: L2_IN_IN
                    always_comb begin
                      case(prec)
                        4'b0000: begin
                          out_tmp[PT4+:PQ4] = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0];

                          out_tmp[PM4+:PQ4] = L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0];

                          out_tmp[PQ4+:PQ4] = L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0];

                          out_tmp[0+:PQ4]   = L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b1010: begin
                          out_tmp[PZ2+:PQ2] = L2_out[0][0][M+:M] + L2_out[0][1][M+:M] + L2_out[0][2][M+:M] + L2_out[0][3][M+:M];
                          out_tmp[PT4+:PQ2] = L2_out[1][0][M+:M] + L2_out[1][1][M+:M] + L2_out[1][2][M+:M] + L2_out[1][3][M+:M];

                          out_tmp[PT2+:PQ2] = L2_out[2][0][M+:M] + L2_out[2][1][M+:M] + L2_out[2][2][M+:M] + L2_out[2][3][M+:M];
                          out_tmp[PM4+:PQ2] = L2_out[3][0][M+:M] + L2_out[3][1][M+:M] + L2_out[3][2][M+:M] + L2_out[3][3][M+:M];

                          out_tmp[PM2+:PQ2] = L2_out[0][0][0+:M] + L2_out[0][1][0+:M] + L2_out[0][2][0+:M] + L2_out[0][3][0+:M];
                          out_tmp[PQ4+:PQ2] = L2_out[1][0][0+:M] + L2_out[1][1][0+:M] + L2_out[1][2][0+:M] + L2_out[1][3][0+:M];

                          out_tmp[PQ2+:PQ2] = L2_out[2][0][0+:M] + L2_out[2][1][0+:M] + L2_out[2][2][0+:M] + L2_out[2][3][0+:M];
                          out_tmp[0+:PQ2]   = L2_out[3][0][0+:M] + L2_out[3][1][0+:M] + L2_out[3][2][0+:M] + L2_out[3][3][0+:M];
                        end
                        4'b1111: begin
                          out_tmp[PZ3+:PQ1] = L2_out[0][0][T+:Q] + L2_out[0][1][T+:Q] + L2_out[0][2][T+:Q] + L2_out[0][3][T+:Q];
                          out_tmp[PZ2+:PQ1] = L2_out[1][0][T+:Q] + L2_out[1][1][T+:Q] + L2_out[1][2][T+:Q] + L2_out[1][3][T+:Q];
                          out_tmp[PZ1+:PQ1] = L2_out[2][0][T+:Q] + L2_out[2][1][T+:Q] + L2_out[2][2][T+:Q] + L2_out[2][3][T+:Q];
                          out_tmp[PT4+:PQ1] = L2_out[3][0][T+:Q] + L2_out[3][1][T+:Q] + L2_out[3][2][T+:Q] + L2_out[3][3][T+:Q];

                          out_tmp[PT3+:PQ1] = L2_out[0][0][M+:Q] + L2_out[0][1][M+:Q] + L2_out[0][2][M+:Q] + L2_out[0][3][M+:Q];
                          out_tmp[PT2+:PQ1] = L2_out[1][0][M+:Q] + L2_out[1][1][M+:Q] + L2_out[1][2][M+:Q] + L2_out[1][3][M+:Q];
                          out_tmp[PT1+:PQ1] = L2_out[2][0][M+:Q] + L2_out[2][1][M+:Q] + L2_out[2][2][M+:Q] + L2_out[2][3][M+:Q];
                          out_tmp[PM4+:PQ1] = L2_out[3][0][M+:Q] + L2_out[3][1][M+:Q] + L2_out[3][2][M+:Q] + L2_out[3][3][M+:Q];

                          out_tmp[PM3+:PQ1] = L2_out[0][0][Q+:Q] + L2_out[0][1][Q+:Q] + L2_out[0][2][Q+:Q] + L2_out[0][3][Q+:Q];
                          out_tmp[PM2+:PQ1] = L2_out[1][0][Q+:Q] + L2_out[1][1][Q+:Q] + L2_out[1][2][Q+:Q] + L2_out[1][3][Q+:Q];
                          out_tmp[PM1+:PQ1] = L2_out[2][0][Q+:Q] + L2_out[2][1][Q+:Q] + L2_out[2][2][Q+:Q] + L2_out[2][3][Q+:Q];
                          out_tmp[PQ4+:PQ1] = L2_out[3][0][Q+:Q] + L2_out[3][1][Q+:Q] + L2_out[3][2][Q+:Q] + L2_out[3][3][Q+:Q];

                          out_tmp[PQ3+:PQ1] = L2_out[0][0][0+:Q] + L2_out[0][1][0+:Q] + L2_out[0][2][0+:Q] + L2_out[0][3][0+:Q];
                          out_tmp[PQ2+:PQ1] = L2_out[1][0][0+:Q] + L2_out[1][1][0+:Q] + L2_out[1][2][0+:Q] + L2_out[1][3][0+:Q];
                          out_tmp[PQ1+:PQ1] = L2_out[2][0][0+:Q] + L2_out[2][1][0+:Q] + L2_out[2][2][0+:Q] + L2_out[2][3][0+:Q];
                          out_tmp[0+:PQ1]   = L2_out[3][0][0+:Q] + L2_out[3][1][0+:Q] + L2_out[3][2][0+:Q] + L2_out[3][3][0+:Q];
                        end
                      endcase
                    end
                  end
                  4'b1111: begin: L2_OUT_OUT
                    always_comb begin
                      out_tmp[PT4+:PQ4] = L2_out[0][0] + L2_out[0][1] + L2_out[0][2] + L2_out[0][3];
                      out_tmp[PM4+:PQ4] = L2_out[1][0] + L2_out[1][1] + L2_out[1][2] + L2_out[1][3];
                      out_tmp[PQ4+:PQ4] = L2_out[2][0] + L2_out[2][1] + L2_out[2][2] + L2_out[2][3];
                      out_tmp[0+:PQ4]   = L2_out[3][0] + L2_out[3][1] + L2_out[3][2] + L2_out[3][3];
                    end
                  end
                endcase
              end
              2'b11: begin: L3_OUT_OUT
                always_comb begin
                  L2_w = '{'{w[3][0], w[2][0], w[1][0], w[0][0]}, 
                           '{w[3][2], w[2][2], w[1][2], w[0][2]}, 
                           '{w[3][1], w[2][1], w[1][1], w[0][1]}, 
                           '{w[3][3], w[2][3], w[1][3], w[0][3]}};
                  
                  L2_a = '{'{a[0][0], a[0][2], a[0][1], a[0][3]}, 
                           '{a[1][0], a[1][2], a[1][1], a[1][3]}, 
                           '{a[2][0], a[2][2], a[2][1], a[2][3]}, 
                           '{a[3][0], a[3][2], a[3][1], a[3][3]}};
                end
                case(L2_MODE)
                  4'b0000: begin: L2_IN_IN
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin
                          out_tmp = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0]
                                  + L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0]
                                  + L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0]
                                  + L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                        end
                        4'b1010: begin
                          out_tmp[PM4+:PM4] = L2_out[0][0][M+:M] + L2_out[0][1][M+:M] + L2_out[0][2][M+:M] + L2_out[0][3][M+:M]
                                            + L2_out[1][0][M+:M] + L2_out[1][1][M+:M] + L2_out[1][2][M+:M] + L2_out[1][3][M+:M]
                                            + L2_out[2][0][M+:M] + L2_out[2][1][M+:M] + L2_out[2][2][M+:M] + L2_out[2][3][M+:M]
                                            + L2_out[3][0][M+:M] + L2_out[3][1][M+:M] + L2_out[3][2][M+:M] + L2_out[3][3][M+:M];
                          out_tmp[0+:PM4]   = L2_out[0][0][0+:M] + L2_out[0][1][0+:M] + L2_out[0][2][0+:M] + L2_out[0][3][0+:M]
                                            + L2_out[1][0][0+:M] + L2_out[1][1][0+:M] + L2_out[1][2][0+:M] + L2_out[1][3][0+:M]
                                            + L2_out[2][0][0+:M] + L2_out[2][1][0+:M] + L2_out[2][2][0+:M] + L2_out[2][3][0+:M]
                                            + L2_out[3][0][0+:M] + L2_out[3][1][0+:M] + L2_out[3][2][0+:M] + L2_out[3][3][0+:M];
                        end
                        4'b1111: begin
                          out_tmp[PT4+:PQ4] = L2_out[0][0][T+:Q] + L2_out[0][1][T+:Q] + L2_out[0][2][T+:Q] + L2_out[0][3][T+:Q]
                                            + L2_out[1][0][T+:Q] + L2_out[1][1][T+:Q] + L2_out[1][2][T+:Q] + L2_out[1][3][T+:Q]
                                            + L2_out[2][0][T+:Q] + L2_out[2][1][T+:Q] + L2_out[2][2][T+:Q] + L2_out[2][3][T+:Q]
                                            + L2_out[3][0][T+:Q] + L2_out[3][1][T+:Q] + L2_out[3][2][T+:Q] + L2_out[3][3][T+:Q];

                          out_tmp[PM4+:PQ4] = L2_out[0][0][M+:Q] + L2_out[0][1][M+:Q] + L2_out[0][2][M+:Q] + L2_out[0][3][M+:Q]
                                            + L2_out[1][0][M+:Q] + L2_out[1][1][M+:Q] + L2_out[1][2][M+:Q] + L2_out[1][3][M+:Q]
                                            + L2_out[2][0][M+:Q] + L2_out[2][1][M+:Q] + L2_out[2][2][M+:Q] + L2_out[2][3][M+:Q]
                                            + L2_out[3][0][M+:Q] + L2_out[3][1][M+:Q] + L2_out[3][2][M+:Q] + L2_out[3][3][M+:Q];

                          out_tmp[PQ4+:PQ4] = L2_out[0][0][Q+:Q] + L2_out[0][1][Q+:Q] + L2_out[0][2][Q+:Q] + L2_out[0][3][Q+:Q]
                                            + L2_out[1][0][Q+:Q] + L2_out[1][1][Q+:Q] + L2_out[1][2][Q+:Q] + L2_out[1][3][Q+:Q]
                                            + L2_out[2][0][Q+:Q] + L2_out[2][1][Q+:Q] + L2_out[2][2][Q+:Q] + L2_out[2][3][Q+:Q]
                                            + L2_out[3][0][Q+:Q] + L2_out[3][1][Q+:Q] + L2_out[3][2][Q+:Q] + L2_out[3][3][Q+:Q];

                          out_tmp[0+:PQ4]   = L2_out[0][0][0+:Q] + L2_out[0][1][0+:Q] + L2_out[0][2][0+:Q] + L2_out[0][3][0+:Q]
                                            + L2_out[1][0][0+:Q] + L2_out[1][1][0+:Q] + L2_out[1][2][0+:Q] + L2_out[1][3][0+:Q]
                                            + L2_out[2][0][0+:Q] + L2_out[2][1][0+:Q] + L2_out[2][2][0+:Q] + L2_out[2][3][0+:Q]
                                            + L2_out[3][0][0+:Q] + L2_out[3][1][0+:Q] + L2_out[3][2][0+:Q] + L2_out[3][3][0+:Q];
                        end
                      endcase
                    end
                  end
                  4'b1111: begin: L2_OUT_OUT
                    always_comb begin
                      out_tmp = L2_out[0][0][15:0] + L2_out[0][1][15:0] + L2_out[0][2][15:0] + L2_out[0][3][15:0]
                              + L2_out[1][0][15:0] + L2_out[1][1][15:0] + L2_out[1][2][15:0] + L2_out[1][3][15:0]
                              + L2_out[2][0][15:0] + L2_out[2][1][15:0] + L2_out[2][2][15:0] + L2_out[2][3][15:0]
                              + L2_out[3][0][15:0] + L2_out[3][1][15:0] + L2_out[3][2][15:0] + L2_out[3][3][15:0];
                    end
                  end
                endcase
              end
            endcase
          end
        endcase
      end
    endcase
  endgenerate
endmodule
