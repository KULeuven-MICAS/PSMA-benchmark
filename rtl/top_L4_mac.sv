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
// File Name: top_L4_mac.sv
// Design:    top_L4_mac
// Function:  Top module for L4_mac which has input registers
//-----------------------------------------------------

import helper::*;

module top_L4_mac (clk, rst, prec, accum_en, a, w, z);

  ///-------------Parameters------------------------------
  parameter       HEADROOM = 4; 
  parameter       L4_MODE  = 2'b00; 
  parameter       L3_MODE  = 2'b00;
  parameter       L2_MODE  = 4'b0000;   // Determines if in/out are shared for x/y dimensions
                                        // 0: input shared, 1: output shared
                                        // MODE[3:2] -> L2_mac, MODE[1:0] -> L1_mult
  parameter       BG     = 2'b00;       // Bitgroups (00: unroll in L2, 01: unroll in L3, 11: Unroll Temporally)
  parameter       DVAFS  = 1'b0;
  parameter       SIZE   = 4; 
  
  //-------------Local parameters------------------------
  localparam      L2_HELP_MODE  = BG[1] ? 4'b1111 : L2_MODE;                          // If Temporal: Choose mode as 4'b1111
  localparam      HEADROOM_HELP = BG[1] ? HEADROOM-4 : HEADROOM;                      // If Temporal: Headroom is partially incorporated in L2
  localparam      L2_A_INPUTS   = helper::get_L2_A_inputs(DVAFS, L2_HELP_MODE);
  localparam      L2_W_INPUTS   = helper::get_L2_W_inputs(DVAFS, L2_HELP_MODE);
  localparam      L2_OUT_WIDTH  = helper::get_L2_out_width(DVAFS, BG, L2_HELP_MODE);  // Width of the multiplication
                                                                                      // See function definitions at helper package
  localparam      L3_A_INPUTS   = helper::get_ARR_A_inputs(L3_MODE);
  localparam      L3_W_INPUTS   = helper::get_ARR_W_inputs(L3_MODE);
  localparam      L3_OUT_WIDTH  = helper::get_L3_out_width(DVAFS, BG, {L3_MODE, L2_HELP_MODE});
  
  localparam      L4_A_INPUTS   = helper::get_ARR_A_inputs(L4_MODE);
  localparam      L4_W_INPUTS   = helper::get_ARR_W_inputs(L4_MODE);
  localparam      L4_OUT_WIDTH  = helper::get_L4_out_width(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, SIZE);
  localparam      L4_MAX_OUTS   = helper::get_L4_max_outs(DVAFS, {L4_MODE, L3_MODE, L2_HELP_MODE}, SIZE);
  
  localparam      Z_WIDTH       = L4_OUT_WIDTH + (L4_MAX_OUTS * HEADROOM_HELP); 
  
  //-------------Inputs----------------------------------
  input            clk, rst, accum_en; 
  input [7:0]      a [SIZE][L4_A_INPUTS][4][L3_A_INPUTS][L2_A_INPUTS];   
  input [7:0]      w [SIZE][L4_W_INPUTS][4][L3_W_INPUTS][L2_W_INPUTS];   
  input [3:0]      prec;        // 9 cases of precision (activation * weight)
                                // prec[3:2]: Activation precision, prec[1:0]: Weight precision
                                // 00: 8b, 10: 4b, 11: 2b
  
  //-------------Outputs---------------------------------
  output [Z_WIDTH-1:0]   z;   
  
  logic             rst_reg;
  logic  [7:0]      a_reg [SIZE][L4_A_INPUTS][4][L3_A_INPUTS][L2_A_INPUTS];   
  logic  [7:0]      w_reg [SIZE][L4_W_INPUTS][4][L3_W_INPUTS][L2_W_INPUTS];   
  logic             accum_en_reg; 



  //-------------Datapath--------------------------------

  //-------------UUT instantiation----------

  L4_mac #(
    // Parameters
    .HEADROOM (HEADROOM_HELP), 
    .L4_MODE  (L4_MODE), 
    .L3_MODE  (L3_MODE),
    .L2_MODE  (L2_HELP_MODE), 
    .BG       (BG), 
    .DVAFS    (DVAFS), 
    .SIZE     (SIZE)
  ) 
  L4 (
    // Inputs
    .clk      (clk), 
    .rst      (rst_reg), 
    .prec     (prec),
    .accum_en (accum_en_reg), 
    .a        (a_reg),
    .w        (w_reg),
    // Outputs
    .z      (z)
  );


  // synchronous rst of the MAC module
  always_ff @(posedge clk)
    rst_reg <= rst;

  // input registers
  always_ff @(posedge clk) begin
    if (rst == 1) begin
      w_reg        <= '{default:0};
      a_reg        <= '{default:0};
      accum_en_reg <= 0; 
    end
    else begin
      w_reg        <= w;
      a_reg        <= a;
      accum_en_reg <= accum_en; 
    end
  end
  
endmodule 
