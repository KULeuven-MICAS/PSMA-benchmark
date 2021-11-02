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
// File Name: L4_mult.sv
// Design:    L4_mult
// Function:  An array of L3_mult 
//-----------------------------------------------------

import helper::*;

module L4_mult (prec, a, w, 
                `ifdef BIT_SERIAL 
                clk, rst, clk_w_strb, clk_z_strb, 
                `endif
                out);
  
  //-------------Parameters------------------------------
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

  // L4_MODE=2'b11 does not add anything to the total # of outputs per precision -> gives # outs for L3
  localparam            L3_OUTS_88    = helper::get_outs_prec(DVAFS, BG, {2'b11, L3_MODE, L2_MODE}, 4'b0000); 
  localparam            L3_OUTS_84    = helper::get_outs_prec(DVAFS, BG, {2'b11, L3_MODE, L2_MODE}, 4'b0010);
  localparam            L3_OUTS_82    = helper::get_outs_prec(DVAFS, BG, {2'b11, L3_MODE, L2_MODE}, 4'b0011); 
  localparam            L3_OUTS_44    = helper::get_outs_prec(DVAFS, BG, {2'b11, L3_MODE, L2_MODE}, 4'b1010);
  localparam            L3_OUTS_22    = helper::get_outs_prec(DVAFS, BG, {2'b11, L3_MODE, L2_MODE}, 4'b1111); 
  // L4_MODE=2'b00 does not add any bits to the output width per precision -> gives L3 output width
  localparam            L3_WIDTH_88   = helper::get_width_prec(DVAFS, BG, {2'b00, L3_MODE, L2_MODE}, 4'b0000); 
  localparam            L3_WIDTH_84   = helper::get_width_prec(DVAFS, BG, {2'b00, L3_MODE, L2_MODE}, 4'b0010); 
  localparam            L3_WIDTH_82   = helper::get_width_prec(DVAFS, BG, {2'b00, L3_MODE, L2_MODE}, 4'b0011); 
  localparam            L3_WIDTH_44   = helper::get_width_prec(DVAFS, BG, {2'b00, L3_MODE, L2_MODE}, 4'b1010); 
  localparam            L3_WIDTH_22   = helper::get_width_prec(DVAFS, BG, {2'b00, L3_MODE, L2_MODE}, 4'b1111); 

  //-------------Inputs----------------------------------
  input    [7:0]        a [SIZE][L4_A_INPUTS][4][L3_A_INPUTS][L2_A_INPUTS];   
  input    [7:0]        w [SIZE][L4_W_INPUTS][4][L3_W_INPUTS][L2_W_INPUTS];   
  input    [3:0]        prec;         // 9 cases of precision (activation * weight)
                                      // prec[3:2]: Activation precision, prec[1:0]: Weight precision
                                      // 00: 8b, 10: 4b, 11: 2b
  
  //-------------Outputs---------------------------------
  output   [L4_OUT_WIDTH-1:0]   out;   
  logic    [L4_OUT_WIDTH-1:0]   out_tmp; 
  
  //-------------Internal Signals------------------------
  
  // L2_mult signals:
  logic    [L3_OUT_WIDTH-1: 0]  L3_out [SIZE][SIZE];

  //-------------Bit-Serial Signals----------------------
  `ifdef BIT_SERIAL 
  input    clk, rst, clk_w_strb, clk_z_strb;
  `endif
  
  //-------------Datapath--------------------------------
  assign out = out_tmp; 

  
  //-------------UUT Instantiation--------------
  genvar L3_x, L3_y;
  generate
    // GENERATE 16x L3_mult modules
    for(L3_x=0; L3_x<SIZE; L3_x++) begin: L3_mult_x
      for(L3_y=0; L3_y<SIZE; L3_y++) begin: L3_mult_y
        L3_mult #(
          // Parameters
          .L3_MODE  (L3_MODE),
          .L2_MODE  (L2_MODE), 
          .BG       (BG), 
          .DVAFS    (DVAFS)
        ) L3 (
          // Inputs
          .prec     (prec),
          // For a & w, I only care about the first 2 dimensions: [SIZE][L4_INPUTS] 
          // The rest of the dimensions are unpacked at L3_mult
          // TODO: Change L3_mult to same notation for consistency - requires changing TB and PB as well 
          .w        (w[SIZE-1-L3_y][L4_MODE[0] ? L3_x:0]), 
          .a        (a[L3_x]       [L4_MODE[1] ? L3_y:0]),
          // Bit-Serial Signals 
          `ifdef BIT_SERIAL
          .clk        (clk), 
          .rst        (rst), 
          .clk_w_strb (clk_w_strb), 
          .clk_z_strb (clk_z_strb), 
          `endif
          // Outputs
          .out      (L3_out[L3_x][L3_y])
        );
      end
    end
  endgenerate
  
  // Should work with all L3, L2, BG parameters! 
  generate
    case(L4_MODE)
      2'b00: begin: L4_IN_IN
        always_comb begin
          out_tmp = {L3_out[0][0], L3_out[0][1], L3_out[0][2], L3_out[0][3], 
                     L3_out[1][0], L3_out[1][1], L3_out[1][2], L3_out[1][3],
                     L3_out[2][0], L3_out[2][1], L3_out[2][2], L3_out[2][3],
                     L3_out[3][0], L3_out[3][1], L3_out[3][2], L3_out[3][3]};
        end
      end
      2'b10: begin: L4_OUT_IN
        always_comb begin
          unique case(prec)
            4'b0000: begin
              for(int i=0; i<L3_OUTS_88; i++) begin
                for(int j=0; j<4; j++) begin
                  out_tmp[((i*(L4_OUT_WIDTH/L3_OUTS_88))+(j*(L4_OUT_WIDTH/(L3_OUTS_88*4))))+:(L4_OUT_WIDTH/(L3_OUTS_88*4))] = 
                      L3_out[3-j][0][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[3-j][1][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[3-j][2][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[3-j][3][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88];  
                end
              end
            end
            4'b0010: begin
              for(int i=0; i<L3_OUTS_84; i++) begin
                for(int j=0; j<4; j++) begin
                  out_tmp[((i*(L4_OUT_WIDTH/L3_OUTS_84))+(j*(L4_OUT_WIDTH/(L3_OUTS_84*4))))+:(L4_OUT_WIDTH/(L3_OUTS_84*4))] = 
                      L3_out[3-j][0][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[3-j][1][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[3-j][2][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[3-j][3][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84];  
                end
              end
            end
            4'b0011: begin
              for(int i=0; i<L3_OUTS_82; i++) begin
                for(int j=0; j<4; j++) begin
                  out_tmp[((i*(L4_OUT_WIDTH/L3_OUTS_82))+(j*(L4_OUT_WIDTH/(L3_OUTS_82*4))))+:(L4_OUT_WIDTH/(L3_OUTS_82*4))] = 
                      L3_out[3-j][0][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[3-j][1][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[3-j][2][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[3-j][3][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82];  
                end
              end
            end
            4'b1010: begin
              for(int i=0; i<L3_OUTS_44; i++) begin
                for(int j=0; j<4; j++) begin
                  out_tmp[((i*(L4_OUT_WIDTH/L3_OUTS_44))+(j*(L4_OUT_WIDTH/(L3_OUTS_44*4))))+:(L4_OUT_WIDTH/(L3_OUTS_44*4))] = 
                      L3_out[3-j][0][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[3-j][1][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[3-j][2][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[3-j][3][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44];  
                end
              end
            end
            4'b1111: begin
              for(int i=0; i<L3_OUTS_22; i++) begin
                for(int j=0; j<4; j++) begin
                  out_tmp[((i*(L4_OUT_WIDTH/L3_OUTS_22))+(j*(L4_OUT_WIDTH/(L3_OUTS_22*4))))+:(L4_OUT_WIDTH/(L3_OUTS_22*4))] = 
                      L3_out[3-j][0][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[3-j][1][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[3-j][2][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[3-j][3][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22];  
                end
              end
            end
          endcase
        end
      end
      2'b11: begin: L4_OUT_OUT
        always_comb begin
          unique case(prec)
            4'b0000: begin
              for(int i=0; i<L3_OUTS_88; i++) begin
                out_tmp[(i*(L4_OUT_WIDTH/L3_OUTS_88))+:(L4_OUT_WIDTH/L3_OUTS_88)] = 
                    L3_out[0][0][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[0][1][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[0][2][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[0][3][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88]  
                  + L3_out[1][0][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[1][1][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[1][2][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[1][3][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] 
                  + L3_out[2][0][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[2][1][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[2][2][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[2][3][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] 
                  + L3_out[3][0][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[3][1][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[3][2][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88] + L3_out[3][3][(i*(L3_OUT_WIDTH/L3_OUTS_88))+:L3_WIDTH_88]; 
              end
            end
            4'b0010: begin
              for(int i=0; i<L3_OUTS_84; i++) begin
                out_tmp[(i*(L4_OUT_WIDTH/L3_OUTS_84))+:(L4_OUT_WIDTH/L3_OUTS_84)] = 
                    L3_out[0][0][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[0][1][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[0][2][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[0][3][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84]  
                  + L3_out[1][0][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[1][1][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[1][2][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[1][3][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] 
                  + L3_out[2][0][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[2][1][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[2][2][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[2][3][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] 
                  + L3_out[3][0][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[3][1][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[3][2][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84] + L3_out[3][3][(i*(L3_OUT_WIDTH/L3_OUTS_84))+:L3_WIDTH_84]; 
              end
            end
            4'b0011: begin
              for(int i=0; i<L3_OUTS_82; i++) begin
                out_tmp[(i*(L4_OUT_WIDTH/L3_OUTS_82))+:(L4_OUT_WIDTH/L3_OUTS_82)] = 
                    L3_out[0][0][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[0][1][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[0][2][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[0][3][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82]  
                  + L3_out[1][0][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[1][1][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[1][2][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[1][3][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] 
                  + L3_out[2][0][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[2][1][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[2][2][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[2][3][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] 
                  + L3_out[3][0][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[3][1][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[3][2][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82] + L3_out[3][3][(i*(L3_OUT_WIDTH/L3_OUTS_82))+:L3_WIDTH_82]; 
              end
            end
            4'b1010: begin
              for(int i=0; i<L3_OUTS_44; i++) begin
                out_tmp[(i*(L4_OUT_WIDTH/L3_OUTS_44))+:(L4_OUT_WIDTH/L3_OUTS_44)] = 
                    L3_out[0][0][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[0][1][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[0][2][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[0][3][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44]  
                  + L3_out[1][0][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[1][1][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[1][2][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[1][3][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] 
                  + L3_out[2][0][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[2][1][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[2][2][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[2][3][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] 
                  + L3_out[3][0][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[3][1][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[3][2][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44] + L3_out[3][3][(i*(L3_OUT_WIDTH/L3_OUTS_44))+:L3_WIDTH_44]; 
              end
            end
            4'b1111: begin
              for(int i=0; i<L3_OUTS_22; i++) begin
                out_tmp[(i*(L4_OUT_WIDTH/L3_OUTS_22))+:(L4_OUT_WIDTH/L3_OUTS_22)] = 
                    L3_out[0][0][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[0][1][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[0][2][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[0][3][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22]  
                  + L3_out[1][0][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[1][1][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[1][2][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[1][3][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] 
                  + L3_out[2][0][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[2][1][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[2][2][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[2][3][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] 
                  + L3_out[3][0][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[3][1][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[3][2][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22] + L3_out[3][3][(i*(L3_OUT_WIDTH/L3_OUTS_22))+:L3_WIDTH_22]; 
              end
            end
          endcase
        end
      end
    endcase
  endgenerate


endmodule