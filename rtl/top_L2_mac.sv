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
// File Name: top_L2_mac.sv
// Design:    top_L2_mac
// Function:  Top module for L2_mac which has input registers
//-----------------------------------------------------

import helper::*;

module top_L2_mac (clk, rst, prec, a, w, z);

    parameter                       HEADROOM = 4;
    parameter                       MODE     = 4'b0000;     // Determines if in/out are shared for x/y dimensions
                                                            // 0: input shared, 1: output shared
                                                            // MODE[3:2] -> L2_mac, MODE[1:0] -> L1_mult
    parameter                       BG       = 2'b00;       // Bitgroups (0: unroll in MAC, 1: unroll out of MAC)
    parameter                       DVAFS    = 1'b0;
    
    //-------------Local parameters------------------------
    localparam                      HEADROOM_HELP = BG[1] ? HEADROOM-4 : HEADROOM; 
    localparam                      HELP_MODE   = (BG[1]) ? 4'b1111 : MODE;
    localparam                      L2_A_INPUTS = helper::get_L2_A_inputs(DVAFS, HELP_MODE);            // No. of A and W inputs is 1 if SA, 
    localparam                      L2_W_INPUTS = helper::get_L2_W_inputs(DVAFS, HELP_MODE);            // 4 if ST, 2 if SA/ST
    localparam                      MAX_OUTPUTS = helper::get_L2_max_out(DVAFS, HELP_MODE);             // Max. number of outputs in each MODE
    localparam                      MULT_WIDTH  = helper::get_L2_out_width(DVAFS, BG, HELP_MODE);    // Width of the 8x8 multiplication (without accumulation)
                                                                                                        // See function definitions at helper package
                                                                                                        
    // localparam                      Z_WIDTH     = (BG[1]) ? MULT_WIDTH + 12 : MULT_WIDTH + (MAX_OUTPUTS * HEADROOM);
    localparam                      Z_WIDTH   = MULT_WIDTH + (MAX_OUTPUTS * HEADROOM_HELP);

    //-------------Inputs----------------------------------
    input                           clk, rst; 
    input      [7:0]                a [L2_A_INPUTS];     
    input      [7:0]                w [L2_W_INPUTS];     
    input      [3:0]                prec;               // 5 supported precisions (activation * weight): 8x8, 8x4, 8x2, 4x4, 2x2
                                                        // prec[3:2]: Activation precision, prec[1:0]: Weight precision
                                                        // 00: 8b, 10: 4b, 11: 2b
    
    //-------------Outputs---------------------------------
    output     [Z_WIDTH-1:0]        z;
    
    logic                           rst_reg;
    logic      [7:0]                a_reg [L2_A_INPUTS];     
    logic      [7:0]                w_reg [L2_W_INPUTS];



    //-------------Datapath--------------------------------

    //-------------UUT instantiation----------

    L2_mac #(
        // Parameters
        .HEADROOM (HEADROOM), 
        .MODE     (HELP_MODE),
        .BG       (BG), 
        .DVAFS    (DVAFS)
    )
    mac (
        // Inputs
        .clk        (clk),
        .rst        (rst_reg),
        .prec       (prec),
        .a          (a_reg),
        .w          (w_reg),
        // Outputs
        .z          (z)
    );


    // synchronous rst of the MAC module
    always_ff @(posedge clk)
        rst_reg <= rst;

    // input registers
    always_ff @(posedge clk) begin
        if (rst == 1) begin
            w_reg             <= '{default:0};
            a_reg             <= '{default:0};

        end
        else begin
            w_reg             <= w;
            a_reg             <= a;
        end
    end
    
endmodule 
