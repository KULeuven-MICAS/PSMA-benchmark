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
// File Name: L2_mult.sv
// Design:    L2_mult
// Function:  8bx8b multiplier supporting SA, ST, and hybrid SA/ST
//-----------------------------------------------------

import helper::*;

module L2_mult (prec, a, w, 
                `ifdef BIT_SERIAL 
                clk, rst, clk_w_strb, clk_z_strb, 
                `endif
                out);
  
  //-------------Parameters------------------------------
  parameter             MODE  = 4'b0000;  // Determines if in/out are shared for x/y dimensions
                                          // 0: input shared, 1: output shared
                                          // MODE[3:2] -> L2_mac, MODE[1:0] -> L1_mult
  parameter             BG    = 2'b00;    // Bitgroups (0: unroll in MAC, 1: unroll out of MAC)
  parameter             DVAFS = 1'b0;
  
  //-------------Local parameters------------------------
  localparam            L1_A_INPUTS   = helper::get_L1_A_inputs(DVAFS, MODE[1:0]);
  localparam            L1_W_INPUTS   = helper::get_L1_W_inputs(DVAFS, MODE[1:0]);
  localparam            L2_A_INPUTS   = helper::get_L2_A_inputs(DVAFS, MODE);			// No. of A and W inputs is 1 if SA, 
  localparam            L2_W_INPUTS   = helper::get_L2_W_inputs(DVAFS, MODE);			// 4 if ST, 2 if SA/ST
  localparam            L1_OUT_WIDTH  = helper::get_L1_out_width(DVAFS, BG[0], MODE);
  localparam            L2_OUT_WIDTH  = helper::get_L2_out_width(DVAFS, BG, MODE);		// Width of the multiplication
                                                  // See function definitions at helper package
  localparam            Q             = L2_OUT_WIDTH * 1/4;
  localparam            M             = L2_OUT_WIDTH * 2/4;
  localparam            T             = L2_OUT_WIDTH * 3/4;
  //-------------Inputs----------------------------------
  input    [7:0]        a [L2_A_INPUTS];   
  input    [7:0]        w [L2_W_INPUTS];   
  input    [3:0]        prec;         // 9 cases of precision (activation * weight)
                                      // prec[3:2]: Activation precision, prec[1:0]: Weight precision
                                      // 00: 8b, 10: 4b, 11: 2b
  
  //-------------Outputs---------------------------------
  

  //-------------Bit-Serial Signals----------------------
  `ifndef BIT_SERIAL 
    output   [L2_OUT_WIDTH-1:0]   out;   
    logic    [L2_OUT_WIDTH-1:0]   out_tmp; 

    assign   out = out_tmp; 
  `else
    input             clk, rst, clk_w_strb, clk_z_strb;
    output   [19:0]   out; 
    logic    [7:0]    out_tmp;             // For multiplier output! 
    logic    [13:0]   a_shift, a_shift_tmp, clk_en_a, clk_gate_a; 
    logic    [5:0]    a_shift_ctrl;        // Upper level (8) -2
    logic    [19:0]   w_shift_tmp, z_op; 
    logic    [19:2]   w_shift, clk_en_w, clk_gate_w; 
    logic    [10:0]   w_shift_ctrl;        // Upper level (14) -2

    assign   out = z_op; 
  `endif
  
  //-------------Internal Signals------------------------
  
  // L1_mult signals:
  logic    [1:0]                L1_prec; 
  logic    [3:0]                L1_a   [2][2][L1_A_INPUTS];
  logic    [3:0]                L1_w   [2][2][L1_W_INPUTS];
  logic    [L1_OUT_WIDTH-1: 0]  L1_out [2][2];
  
  
  //-------------Datapath--------------------------------
  assign L1_prec = {prec[2], prec[0]};    // Only 4 modes in L1: 4x4, 4x2, 2x4, 2x2
                                          // 8b gets cast to 4b in L1 mac
  
  //-------------UUT Instantiation--------------
  
  generate
    // GENERATE 4x L1_mult modules
    for(genvar L1_x=0; L1_x<2; L1_x++) begin: L1_mult_x
      for(genvar L1_y=0; L1_y<2; L1_y++) begin: L1_mult_y
        L1_mult #(
          // Parameters
          .MODE   (MODE[1:0]),
          .BG     (BG), 
          .DVAFS  (DVAFS)
        ) L1 (
          // Inputs
          .prec   (L1_prec),
          .w      (L1_w[L1_x][L1_y]), 
          .a      (L1_a[L1_x][L1_y]),
          // Outputs
          .out    (L1_out[L1_x][L1_y])
        );
      end
    end
  endgenerate
  
  // TODO: Decouple L1_inputs from L2_inputs - this will keep the code much more readable! 
  generate
    case(DVAFS)
      1'b0: begin: DVAFS_OFF
        case(BG[0])
          1'b0: begin: BG_MAC
            case({MODE[3], MODE[2]})
              2'b00: begin: L2_IN_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // L2_OUT_WIDTH = 64-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                               '{'{w[0][7:4]}, '{w[0][3:0]}}};
                      L1_a = '{'{'{a[0][3:0]}, '{a[0][3:0]}}, 
                               '{'{a[0][7:4]}, '{a[0][7:4]}}};
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned({L1_out[1][0],4'b0});
                          out_tmp[0+:M] = $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][1],4'b0});
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[T+:Q] = $unsigned(L1_out[0][0][15:8]) + $unsigned({L1_out[1][0][15:8],4'b0});
                          out_tmp[M+:Q] = $unsigned(L1_out[0][0][7:0])  + $unsigned({L1_out[1][0][7:0],4'b0});
                          out_tmp[Q+:Q] = $unsigned(L1_out[0][1][15:8]) + $unsigned({L1_out[1][1][15:8],4'b0});
                          out_tmp[0+:Q] = $unsigned(L1_out[0][1][7:0])  + $unsigned({L1_out[1][1][7:0],4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[T+:Q] = L1_out[0][0];
                          out_tmp[M+:Q] = L1_out[0][1];
                          out_tmp[Q+:Q] = L1_out[1][0];
                          out_tmp[0+:Q] = L1_out[1][1];
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[T+:Q] = L1_out[0][0];
                          out_tmp[M+:Q] = L1_out[0][1];
                          out_tmp[Q+:Q] = L1_out[1][0];
                          out_tmp[0+:Q] = L1_out[1][1];
                        end
                      endcase
                    end
                  end
                  2'b10: begin: L1_OUT_IN  // L2_OUT_WIDTH = 40-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                          '{'{w[0][7:4]}, '{w[0][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[1][3:0]}, '{a[0][3:0], a[1][3:0]}}, 
                          '{'{a[0][7:4], a[1][7:4]}, '{a[0][7:4], a[1][7:4]}}};
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned({L1_out[1][0],4'b0});
                          out_tmp[0+:M] = $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][1],4'b0});
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned({L1_out[1][0],4'b0});
                          out_tmp[0+:M] = $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][1],4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[T+:Q] = L1_out[0][0];
                          out_tmp[M+:Q] = L1_out[0][1];
                          out_tmp[Q+:Q] = L1_out[1][0];
                          out_tmp[0+:Q] = L1_out[1][1];
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[T+:Q] = L1_out[0][0];
                          out_tmp[M+:Q] = L1_out[0][1];
                          out_tmp[Q+:Q] = L1_out[1][0];
                          out_tmp[0+:Q] = L1_out[1][1];
                        end
                      endcase
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // L2_OUT_WIDTH = 32-bits  (4x4)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4], w[1][7:4]}, '{w[0][3:0], w[1][3:0]}}, 
                          '{'{w[0][7:4], w[1][7:4]}, '{w[0][3:0], w[1][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[1][3:0]}, '{a[0][3:0], a[1][3:0]}}, 
                          '{'{a[0][7:4], a[1][7:4]}, '{a[0][7:4], a[1][7:4]}}};
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned({L1_out[1][0],4'b0});
                          out_tmp[0+:M] = $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][1],4'b0});
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned({L1_out[1][0],4'b0});
                          out_tmp[0+:M] = $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][1],4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[T+:Q] = L1_out[0][0];
                          out_tmp[M+:Q] = L1_out[0][1];
                          out_tmp[Q+:Q] = L1_out[1][0];
                          out_tmp[0+:Q] = L1_out[1][1];
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[T+:Q] = L1_out[0][0];
                          out_tmp[M+:Q] = L1_out[0][1];
                          out_tmp[Q+:Q] = L1_out[1][0];
                          out_tmp[0+:Q] = L1_out[1][1];
                        end
                      endcase
                    end
                  end
                endcase
              end
              
              
              2'b10: begin: L2_OUT_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // L2_OUT_WIDTH = 40-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                          '{'{w[0][7:4]}, '{w[0][3:0]}}};
                      L1_a = '{'{'{a[0][3:0]}, '{a[prec[1]][3:0]}}, 
                          '{'{a[0][7:4]}, '{a[prec[1]][7:4]}}};
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0][15:8]) + $unsigned(L1_out[0][1][15:8]) + $unsigned({L1_out[1][0][15:8], 4'b0}) + $unsigned({L1_out[1][1][15:8], 4'b0});
                          out_tmp[0+:M] = $unsigned(L1_out[0][0][7:0])  + $unsigned(L1_out[0][1][7:0])  + $unsigned({L1_out[1][0][7:0], 4'b0})  + $unsigned({L1_out[1][1][7:0], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]);
                          out_tmp[0+:M] = $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[7*Q/2+:Q/2] = $unsigned(L1_out[0][0][15:12]) + $unsigned(L1_out[0][1][15:12]);
                          out_tmp[T+:Q/2]   = $unsigned(L1_out[1][0][15:12]) + $unsigned(L1_out[1][1][15:12]);
                          out_tmp[5*Q/2+:Q/2] = $unsigned(L1_out[0][0][11:8])  + $unsigned(L1_out[0][1][11:8]);
                          out_tmp[M+:Q/2]   = $unsigned(L1_out[1][0][11:8])  + $unsigned(L1_out[1][1][11:8]);
                          out_tmp[3*Q/2+:Q/2] = $unsigned(L1_out[0][0][7:4])   + $unsigned(L1_out[0][1][7:4]);
                          out_tmp[Q+:Q/2]   = $unsigned(L1_out[1][0][7:4])   + $unsigned(L1_out[1][1][7:4]);
                          out_tmp[Q/2+:Q/2]   = $unsigned(L1_out[0][0][3:0])   + $unsigned(L1_out[0][1][3:0]);
                          out_tmp[0+:Q/2]   = $unsigned(L1_out[1][0][3:0])   + $unsigned(L1_out[1][1][3:0]);
                        end
                      endcase
                    end
                  end
                  2'b10: begin: L1_OUT_IN  // L2_OUT_WIDTH = 24-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                           '{'{w[0][7:4]}, '{w[0][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[2][3:0]}, '{a[prec[1]][3:0], a[3][3:0]}}, 
                           '{'{a[0][7:4], a[2][7:4]}, '{a[prec[1]][7:4], a[3][7:4]}}};
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]);
                          out_tmp[0+:M] = $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[T+:Q] = $unsigned(L1_out[0][0][9:5]) + $unsigned(L1_out[0][1][9:5]);
                          out_tmp[M+:Q] = $unsigned(L1_out[0][0][4:0]) + $unsigned(L1_out[0][1][4:0]);
                          out_tmp[Q+:Q] = $unsigned(L1_out[1][0][9:5]) + $unsigned(L1_out[1][1][9:5]);
                          out_tmp[0+:Q] = $unsigned(L1_out[1][0][4:0]) + $unsigned(L1_out[1][1][4:0]);
                        end
                      endcase
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // L2_OUT_WIDTH = 18-bits (4x4)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4], w[1][7:4]}, '{w[0][3:0], w[1][3:0]}}, 
                          '{'{w[0][7:4], w[1][7:4]}, '{w[0][3:0], w[1][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[2][3:0]}, '{a[prec[1]][3:0], a[3][3:0]}}, 
                          '{'{a[0][7:4], a[2][7:4]}, '{a[prec[1]][7:4], a[3][7:4]}}};
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]);
                          out_tmp[0+:M] = $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]);
                          out_tmp[0+:M] = $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                        end
                      endcase
                    end
                  end
                endcase
              end
              
              2'b11: begin: L2_OUT_OUT
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // L2_OUT_WIDTH = 24-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]},     '{w[0][3:0]}}, 
                          '{'{w[prec[3]][7:4]}, '{w[prec[3]][3:0]}}};
                      L1_a = '{'{'{a[0][3:0]},     '{a[prec[1]][3:0]}}, 
                          '{'{a[0][7:4]},     '{a[prec[1]][7:4]}}};
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0][15:8]) + $unsigned(L1_out[0][1][15:8]) + $unsigned({L1_out[1][0][15:8], 4'b0}) + $unsigned({L1_out[1][1][15:8], 4'b0});
                          out_tmp[0+:M] = $unsigned(L1_out[0][0][7:0])  + $unsigned(L1_out[0][1][7:0])  + $unsigned({L1_out[1][0][7:0], 4'b0})  + $unsigned({L1_out[1][1][7:0], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[T+:Q] = $unsigned(L1_out[0][0][15:12]) + $unsigned(L1_out[0][1][15:12]) + $unsigned(L1_out[1][0][15:12]) + $unsigned(L1_out[1][1][15:12]);
                          out_tmp[M+:Q] = $unsigned(L1_out[0][0][11:8])  + $unsigned(L1_out[0][1][11:8])  + $unsigned(L1_out[1][0][11:8])  + $unsigned(L1_out[1][1][11:8]);
                          out_tmp[Q+:Q] = $unsigned(L1_out[0][0][7:4])   + $unsigned(L1_out[0][1][7:4])   + $unsigned(L1_out[1][0][7:4])   + $unsigned(L1_out[1][1][7:4]);
                          out_tmp[0+:Q] = $unsigned(L1_out[0][0][3:0])   + $unsigned(L1_out[0][1][3:0])   + $unsigned(L1_out[1][0][3:0])   + $unsigned(L1_out[1][1][3:0]);
                        end
                      endcase
                    end
                  end
                  2'b10: begin: L1_OUT_IN  // L2_OUT_WIDTH = 16-bits (8x8)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]},     '{w[0][3:0]}}, 
                          '{'{w[prec[3]][7:4]}, '{w[prec[3]][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[2][3:0]},     '{a[prec[1]][3:0], a[3][3:0]}}, 
                          '{'{a[0][7:4], a[2][7:4]},     '{a[prec[1]][7:4], a[3][7:4]}}};
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0][9:5]) + $unsigned(L1_out[0][1][9:5]) + $unsigned(L1_out[1][0][9:5]) + $unsigned(L1_out[1][1][9:5]);
                          out_tmp[0+:M] = $unsigned(L1_out[0][0][4:0]) + $unsigned(L1_out[0][1][4:0]) + $unsigned(L1_out[1][0][4:0]) + $unsigned(L1_out[1][1][4:0]);
                        end
                      endcase
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // L2_OUT_WIDTH = 16-bits (8x8)
                    always_comb begin
                      L1_w = '{'{'{w[0]    [7:4], w[2][7:4]}, '{w[0]    [3:0], w[2][3:0]}}, 
                          '{'{w[prec[3]][7:4], w[3][7:4]}, '{w[prec[3]][3:0], w[3][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[2][3:0]},     '{a[prec[1]][3:0], a[3][3:0]}}, 
                          '{'{a[0][7:4], a[2][7:4]},     '{a[prec[1]][7:4], a[3][7:4]}}};
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0010: begin  // 8bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b0011: begin  // 8bx2b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 4'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                        end
                      endcase
                    end
                  end
                endcase
              end
            endcase
          end
          
          1'b1: begin: BG_ARR
            case({MODE[3], MODE[2]})
              2'b00: begin: L2_IN_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // L2_OUT_WIDTH = 64-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                          '{'{w[0][7:4]}, '{w[0][3:0]}}};
                      L1_a = '{'{'{a[0][3:0]}, '{a[0][3:0]}}, 
                          '{'{a[0][7:4]}, '{a[0][7:4]}}};
                      out_tmp[T+:Q] = L1_out[0][0];
                      out_tmp[M+:Q] = L1_out[0][1];
                      out_tmp[Q+:Q] = L1_out[1][0];
                      out_tmp[0+:Q] = L1_out[1][1];
                    end
                  end
                  2'b10: begin: L1_OUT_IN  // L2_OUT_WIDTH = 40-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                          '{'{w[0][7:4]}, '{w[0][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[1][3:0]}, '{a[0][3:0], a[1][3:0]}}, 
                          '{'{a[0][7:4], a[1][7:4]}, '{a[0][7:4], a[1][7:4]}}};
                      out_tmp[T+:Q] = L1_out[0][0];
                      out_tmp[M+:Q] = L1_out[0][1];
                      out_tmp[Q+:Q] = L1_out[1][0];
                      out_tmp[0+:Q] = L1_out[1][1];
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // L2_OUT_WIDTH = 24-bits  (4x4)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4], w[1][7:4]}, '{w[0][3:0], w[1][3:0]}}, 
                          '{'{w[0][7:4], w[1][7:4]}, '{w[0][3:0], w[1][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[1][3:0]}, '{a[0][3:0], a[1][3:0]}}, 
                          '{'{a[0][7:4], a[1][7:4]}, '{a[0][7:4], a[1][7:4]}}};
                      out_tmp[T+:Q] = L1_out[0][0];
                      out_tmp[M+:Q] = L1_out[0][1];
                      out_tmp[Q+:Q] = L1_out[1][0];
                      out_tmp[0+:Q] = L1_out[1][1];
                    end
                  end
                endcase
              end
              2'b10: begin: L2_OUT_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // L2_OUT_WIDTH = 40-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                          '{'{w[0][7:4]}, '{w[0][3:0]}}};
                      L1_a = '{'{'{a[0][3:0]}, '{a[1][3:0]}}, 
                          '{'{a[0][7:4]}, '{a[1][7:4]}}};
                      out_tmp[7*Q/2+:Q/2] = $unsigned(L1_out[0][0][15:12]) + $unsigned(L1_out[0][1][15:12]);
                      out_tmp[T+:Q/2]   = $unsigned(L1_out[1][0][15:12]) + $unsigned(L1_out[1][1][15:12]);
                      out_tmp[5*Q/2+:Q/2] = $unsigned(L1_out[0][0][11:8])  + $unsigned(L1_out[0][1][11:8]);
                      out_tmp[M+:Q/2]   = $unsigned(L1_out[1][0][11:8])  + $unsigned(L1_out[1][1][11:8]);
                      out_tmp[3*Q/2+:Q/2] = $unsigned(L1_out[0][0][7:4])   + $unsigned(L1_out[0][1][7:4]);
                      out_tmp[Q+:Q/2]   = $unsigned(L1_out[1][0][7:4])   + $unsigned(L1_out[1][1][7:4]);
                      out_tmp[Q/2+:Q/2]   = $unsigned(L1_out[0][0][3:0])   + $unsigned(L1_out[0][1][3:0]);
                      out_tmp[0+:Q/2]   = $unsigned(L1_out[1][0][3:0])   + $unsigned(L1_out[1][1][3:0]);
                    end
                  end
                  2'b10: begin: L1_OUT_IN  // L2_OUT_WIDTH = 24-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                          '{'{w[0][7:4]}, '{w[0][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[2][3:0]}, '{a[1][3:0], a[3][3:0]}}, 
                          '{'{a[0][7:4], a[2][7:4]}, '{a[1][7:4], a[3][7:4]}}};
                      out_tmp[T+:Q] = $unsigned(L1_out[0][0][9:5]) + $unsigned(L1_out[0][1][9:5]);
                      out_tmp[M+:Q] = $unsigned(L1_out[0][0][4:0]) + $unsigned(L1_out[0][1][4:0]);
                      out_tmp[Q+:Q] = $unsigned(L1_out[1][0][9:5]) + $unsigned(L1_out[1][1][9:5]);
                      out_tmp[0+:Q] = $unsigned(L1_out[1][0][4:0]) + $unsigned(L1_out[1][1][4:0]);
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // L2_OUT_WIDTH = 14-bits (4x4)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4], w[1][7:4]}, '{w[0][3:0], w[1][3:0]}}, 
                          '{'{w[0][7:4], w[1][7:4]}, '{w[0][3:0], w[1][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[2][3:0]}, '{a[1][3:0], a[3][3:0]}}, 
                          '{'{a[0][7:4], a[2][7:4]}, '{a[1][7:4], a[3][7:4]}}};
                      out_tmp[M+:M] = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]);
                      out_tmp[0+:M] = $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                    end
                  end
                endcase
              end
              2'b11: begin: L2_OUT_OUT
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // L2_OUT_WIDTH = 24-bits (2x2)
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                          '{'{w[1][7:4]}, '{w[1][3:0]}}};
                      L1_a = '{'{'{a[0][3:0]}, '{a[1][3:0]}}, 
                          '{'{a[0][7:4]}, '{a[1][7:4]}}};
                      out_tmp[T+:Q] = $unsigned(L1_out[0][0][15:12]) + $unsigned(L1_out[0][1][15:12]) + $unsigned(L1_out[1][0][15:12]) + $unsigned(L1_out[1][1][15:12]);
                      out_tmp[M+:Q] = $unsigned(L1_out[0][0][11:8])  + $unsigned(L1_out[0][1][11:8])  + $unsigned(L1_out[1][0][11:8])  + $unsigned(L1_out[1][1][11:8]);
                      out_tmp[Q+:Q] = $unsigned(L1_out[0][0][7:4])   + $unsigned(L1_out[0][1][7:4])   + $unsigned(L1_out[1][0][7:4])   + $unsigned(L1_out[1][1][7:4]);
                      out_tmp[0+:Q] = $unsigned(L1_out[0][0][3:0])   + $unsigned(L1_out[0][1][3:0])   + $unsigned(L1_out[1][0][3:0])   + $unsigned(L1_out[1][1][3:0]);
                    end
                  end
                  2'b10: begin: L1_OUT_IN  // L2_OUT_WIDTH = 14-bits
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4]}, '{w[0][3:0]}}, 
                          '{'{w[1][7:4]}, '{w[1][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[2][3:0]}, '{a[1][3:0], a[3][3:0]}}, 
                          '{'{a[0][7:4], a[2][7:4]}, '{a[1][7:4], a[3][7:4]}}};
                      out_tmp[M+:M] = $unsigned(L1_out[0][0][9:5]) + $unsigned(L1_out[0][1][9:5]) + $unsigned(L1_out[1][0][9:5]) + $unsigned(L1_out[1][1][9:5]);
                      out_tmp[0+:M] = $unsigned(L1_out[0][0][4:0]) + $unsigned(L1_out[0][1][4:0]) + $unsigned(L1_out[1][0][4:0]) + $unsigned(L1_out[1][1][4:0]);
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // L2_OUT_WIDTH = 8-bits
                    always_comb begin
                      L1_w = '{'{'{w[0][7:4], w[2][7:4]}, '{w[0][3:0], w[2][3:0]}}, 
                          '{'{w[1][7:4], w[3][7:4]}, '{w[1][3:0], w[3][3:0]}}};
                      L1_a = '{'{'{a[0][3:0], a[2][3:0]}, '{a[1][3:0], a[3][3:0]}}, 
                          '{'{a[0][7:4], a[2][7:4]}, '{a[1][7:4], a[3][7:4]}}};
                      out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[0][1]) + $unsigned(L1_out[1][0]) + $unsigned(L1_out[1][1]);
                    end
                  end
                endcase
              end
            endcase
            `ifdef BIT_SERIAL
              // always_comb begin
              //   clk_gate_a  = {14{clk}} & clk_en_a;
              //   clk_gate_w  = {18{clk}} & clk_en_w;
              // end
              
              // always_comb begin //TODO: Might need a rst here (rst -> clk_en = '1) 
              //   clk_en_a[13-:8] = '1;
              //   clk_en_a[5:4]   = {2{~prec[0]}};
              //   clk_en_a[3:0]   = {4{~prec[1]}};
                
              //   clk_en_w[19-:10] = {10{~prec[2]}};
              //   clk_en_w[9:8]    = {2{~prec[3]}};
              //   clk_en_w[7:6]    = {2{!prec[3]&!prec[0]}};
              //   clk_en_w[5:2]    = {4{~prec[1]}};
              // end
              
              for(genvar i=0; i<14; i++) begin
                always_ff @(posedge clk) begin
                  if (rst)  a_shift[i] <= '0; 
                  else      a_shift[i] <= a_shift_tmp[i]; 
                end
              end
              for(genvar i=2; i<20; i++) begin
                always_ff @(posedge clk) begin
                  if (rst || clk_z_strb)  w_shift[i] <= '0; 
                  else if(clk_w_strb)     w_shift[i] <= w_shift_tmp[i]; 
                end
              end
              
              always_comb begin
                a_shift_ctrl     = (clk_w_strb) ? '0 : a_shift[13-:6];
                // Most-Significant  8-bits: Addition
                a_shift_tmp[13-:8] = $unsigned(out_tmp) + $unsigned(a_shift_ctrl);
                // Least-Significant 6-bits: Shifting
                a_shift_tmp[0+:6]  = (clk_w_strb) ? '0 : a_shift[2+:6]; 
              end
              always_comb begin
                w_shift_ctrl    = w_shift[19-:12];
                // Most-Significant  14-bits: Addition
                w_shift_tmp[19-:14] = $unsigned(a_shift) + $unsigned(w_shift_ctrl);
                // Least-Significant 6-bits: Shifting
                w_shift_tmp[0+:6]   = w_shift[2+:6]; 
              end
              always_comb begin
                unique case(prec) 
                  4'b0000: z_op = w_shift_tmp; 
                  4'b0010: z_op = w_shift_tmp >> 4; 
                  4'b0011: z_op = w_shift_tmp >> 6; 
                  4'b1010: z_op = w_shift_tmp >> 8; 
                  4'b1111: z_op = w_shift_tmp >> 12; 
                  default: z_op = w_shift_tmp; 
                endcase
              end
            `endif
          end
        endcase
      end
    
    
      1'b1: begin: DVAFS_ON
        case(BG[0])
          1'b0: begin: BG_MAC
            always_comb begin
            L1_w = '{'{'{w[0][7:4]},         '{w[0][3:0] & {4{~prec[3]}}}}, 
                 '{'{w[0][7:4] & {4{~prec[3]}}}, '{w[0][3:0]}}};
            L1_a = '{'{'{a[0][3:0]},         '{a[0][3:0] & {4{~prec[3]}}}}, 
                 '{'{a[0][7:4] & {4{~prec[3]}}}, '{a[0][7:4]}}};
            end
            case({MODE[3], MODE[2]})
              2'b00: begin: L2_IN_IN
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // L2_OUT_WIDTH = 64-bits (2x2)
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[M+:M] = L1_out[0][0];
                          out_tmp[0+:M] = L1_out[1][1];
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[M+:M] = L1_out[0][0];
                          out_tmp[0+:M] = L1_out[1][1];
                        end
                      endcase
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // L2_OUT_WIDTH = 32-bits  (4x4)
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp[M+:M] = L1_out[0][0];
                          out_tmp[0+:M] = L1_out[1][1];
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[M+:M] = L1_out[0][0];
                          out_tmp[0+:M] = L1_out[1][1];
                        end
                      endcase
                    end
                  end
                endcase
              end
              
              2'b11: begin: L2_OUT_OUT
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // L2_OUT_WIDTH = 24-bits (2x2)
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[1][1]);
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp[M+:M] = $unsigned(L1_out[0][0][7:4]) + $unsigned(L1_out[1][1][7:4]);
                          out_tmp[0+:M] = $unsigned(L1_out[0][0][3:0]) + $unsigned(L1_out[1][1][3:0]);
                        end
                      endcase
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // L2_OUT_WIDTH = 16-bits (8x8)
                    always_comb begin
                      unique case(prec)
                        4'b0000: begin  // 8bx8b
                          out_tmp = $unsigned({L1_out[0][0], 4'b0}) + $unsigned(L1_out[0][1]) + $unsigned({L1_out[1][0], 8'b0}) + $unsigned({L1_out[1][1], 4'b0});
                        end
                        4'b1010: begin  // 4bx4b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[1][1]);
                        end
                        4'b1111: begin  // 2bx2b
                          out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[1][1]);
                        end
                      endcase
                    end
                  end
                endcase
              end
            endcase
          end
          
          1'b1: begin: BG_ARR
            always_comb begin
            L1_w = '{'{'{w[0][7:4]}, '{4'b0000}}, 
                 '{'{4'b0000},   '{w[0][3:0]}}};
            L1_a = '{'{'{a[0][3:0]}, '{4'b0000}}, 
                 '{'{4'b0000},   '{a[0][7:4]}}};
            end
            case({MODE[3], MODE[2]})
              2'b00: begin: L2_IN_IN
                always_comb begin
                  out_tmp[M+:M] = L1_out[0][0];
                  out_tmp[0+:M] = L1_out[1][1];
                end
              end
              2'b11: begin: L2_OUT_OUT
                case({MODE[1], MODE[0]})
                  2'b00: begin: L1_IN_IN  // L2_OUT_WIDTH = 24-bits (2x2)
                    always_comb begin
                      out_tmp[M+:M] = $unsigned(L1_out[0][0][7:4]) + $unsigned(L1_out[1][1][7:4]);
                      out_tmp[0+:M] = $unsigned(L1_out[0][0][3:0]) + $unsigned(L1_out[4][1][3:0]);
                    end
                  end
                  2'b11: begin: L1_OUT_OUT  // L2_OUT_WIDTH = 8-bits
                    always_comb begin
                      out_tmp = $unsigned(L1_out[0][0]) + $unsigned(L1_out[1][1]);
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