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
// File Name: L1_mult.sv
// Design:    L1_mult
// Function:  4bx4b multiplier supporting SA-ST
//-----------------------------------------------------

import helper::*;

module L1_mult (prec, a, w, out);

    //-------------Parameters------------------------------
    parameter                     MODE  = 2'b00;       // Determines if in/out are shared for x/y dimensions
                                                       // 0: input shared, 1: output shared
    parameter                     BG    = 2'b0;        // Bitgroups (0: unroll in MAC, 1: unroll out of MAC)
    parameter                     DVAFS = 1'b0; 
    
    //-------------Local parameters------------------------
    localparam                    L1_A_INPUTS = helper::get_L1_A_inputs(DVAFS, MODE);
    localparam                    L1_W_INPUTS = helper::get_L1_W_inputs(DVAFS, MODE);
    localparam                    OUT_WIDTH   = helper::get_L1_out_width(DVAFS, BG, MODE);  // 16 if fully SA, 10 if SA/ST hybrid
                                                                                            // 8 if ST & BG in MAC, 6 if ST & BG out of MAC
    
    //-------------Inputs----------------------------------
    input      [3:0]              a [L1_A_INPUTS];  // 2 4-bit inputs  if ST, 1 if SA (x-dim)
    input      [3:0]              w [L1_W_INPUTS];  // 2 4-bit weights if ST, 1 if SA (y-dim)
    input      [1:0]              prec;             // 3 cases of precision (activation * weight)
                                                    // 00: 4x4, 01: 4x2, 11: 2x2
    
    //-------------Outputs---------------------------------
    output     [OUT_WIDTH-1:0]    out; 
    logic      [OUT_WIDTH-1:0]    out_tmp; 
    
    //-------------Internal Signals------------------------
    
    // 2b multiplier:
    logic      [1:0]              mult_w [2][2];
    logic      [1:0]              mult_a [2][2];
    logic      [3:0]              mult_z [2][2];
    
    //-------------Datapath--------------------------------
    
    //-------------UUT Instantiation--------------
    
    assign out = out_tmp; 

    genvar mult_gen_x, mult_gen_y;
    generate
        // GENERATE 4x mult_2b modules
        for(mult_gen_x=0; mult_gen_x<2; mult_gen_x++) begin: mult_2b_x
            for(mult_gen_y=0; mult_gen_y<2; mult_gen_y++) begin: mult_2b_y
                mult_2b mult (
                    .w        (mult_w[mult_gen_x][mult_gen_y]), 
                    .a        (mult_a[mult_gen_x][mult_gen_y]),
                    // Outputs
                    .out      (mult_z[mult_gen_x][mult_gen_y])
                );
            end
        end
    endgenerate
    
    generate
        case(DVAFS)
            1'b0: begin: DVAFS_OFF
                case(BG[0])
                    1'b0: begin: BG_MAC
                        case(MODE)
                            2'b00: begin: IN_IN
                                always_comb begin
                                    mult_w = '{'{w[0][3:2], w[0][1:0]}, 
                                               '{w[0][3:2], w[0][1:0]}};
                                    mult_a = '{'{a[0][1:0], a[0][1:0]}, 
                                               '{a[0][3:2], a[0][3:2]}};
                                    unique case(prec)
                                        2'b00: // 4b*4b
                                            out_tmp = $unsigned({mult_z[0][0], 2'b0}) + $unsigned(mult_z[0][1]) + $unsigned({mult_z[1][0], 4'b0}) + $unsigned({mult_z[1][1], 2'b0});
                                        2'b01: begin // 4b*2b
                                            out_tmp [15:8] = $unsigned(mult_z[0][0]) + $unsigned({mult_z[1][0], 2'b0});
                                            out_tmp [7:0]  = $unsigned(mult_z[0][1]) + $unsigned({mult_z[1][1], 2'b0});
                                        end
                                        2'b11: begin // 2b*2b
                                            out_tmp [15:12] = mult_z[0][0];
                                            out_tmp [11:8]  = mult_z[0][1];
                                            out_tmp [7:4]   = mult_z[1][0];
                                            out_tmp [3:0]   = mult_z[1][1];
                                        end
                                    endcase
                                end
                            end
                            
                            2'b10: begin: OUT_IN
                                always_comb begin
                                    mult_w = '{'{w[0][3:2], w[0][1:0]}, 
                                               '{w[0][3:2], w[0][1:0]}};
                                    mult_a = '{'{a[0][1:0], a[prec[0]][1:0]}, 
                                               '{a[0][3:2], a[prec[0]][3:2]}};
                                    unique case(prec)
                                        2'b00: // 4b*4b
                                            out_tmp = $unsigned({mult_z[0][0], 2'b0}) + $unsigned(mult_z[0][1]) + $unsigned({mult_z[1][0], 4'b0}) + $unsigned({mult_z[1][1], 2'b0});
                                        2'b01: // 4b*2b
                                            out_tmp = $unsigned(mult_z[0][0]) + $unsigned(mult_z[0][1]) + $unsigned({mult_z[1][0], 2'b0}) + $unsigned({mult_z[1][1], 2'b0});
                                        2'b11: begin // 2b*2b
                                            out_tmp[9:5] = $unsigned(mult_z[0][0]) + $unsigned(mult_z[0][1]);
                                            out_tmp[4:0] = $unsigned(mult_z[1][0]) + $unsigned(mult_z[1][1]);
                                        end
                                    endcase
                                end
                            end
                            
                            2'b11: begin: OUT_OUT
                                always_comb begin
                                    mult_w = '{'{w[0]      [3:2], w[0]      [1:0]}, 
                                               '{w[prec[1]][3:2], w[prec[1]][1:0]}};
                                    mult_a = '{'{a[0]      [1:0], a[prec[0]][1:0]}, 
                                               '{a[0]      [3:2], a[prec[0]][3:2]}};
                                    unique case(prec)
                                        2'b00: // 4b*4b
                                            out_tmp = $unsigned({mult_z[0][0], 2'b0}) + $unsigned(mult_z[0][1]) + $unsigned({mult_z[1][0], 4'b0}) + $unsigned({mult_z[1][1], 2'b0});
                                        2'b01: // 4b*2b
                                            out_tmp = $unsigned(mult_z[0][0]) + $unsigned(mult_z[0][1]) + $unsigned({mult_z[1][0], 2'b0}) + $unsigned({mult_z[1][1], 2'b0});
                                        2'b11: // 2b*2b
                                            out_tmp = $unsigned(mult_z[0][0]) + $unsigned(mult_z[0][1]) + $unsigned(mult_z[1][0]) + $unsigned(mult_z[1][1]);
                                    endcase
                                end
                            end
                        endcase
                    end
                    
                    1'b1: begin: BG_ARR
                        case(MODE)
                            2'b00: begin: IN_IN
                                always_comb begin
                                    mult_w = '{'{w[0][3:2], w[0][1:0]}, 
                                               '{w[0][3:2], w[0][1:0]}};
                                    mult_a = '{'{a[0][1:0], a[0][1:0]}, 
                                               '{a[0][3:2], a[0][3:2]}};
                                    out_tmp [15:12] = mult_z[0][0];
                                    out_tmp [11:8]  = mult_z[0][1];
                                    out_tmp [7:4]   = mult_z[1][0];
                                    out_tmp [3:0]   = mult_z[1][1];
                                end
                            end
                            
                            2'b10: begin: OUT_IN
                                always_comb begin
                                    mult_w = '{'{w[0][3:2], w[0][1:0]}, 
                                               '{w[0][3:2], w[0][1:0]}};
                                    mult_a = '{'{a[0][1:0], a[1][1:0]}, 
                                               '{a[0][3:2], a[1][3:2]}};
                                    out_tmp[9:5] = $unsigned(mult_z[0][0]) + $unsigned(mult_z[0][1]);
                                    out_tmp[4:0] = $unsigned(mult_z[1][0]) + $unsigned(mult_z[1][1]);
                                end
                            end
                            
                            2'b11: begin: OUT_OUT
                                always_comb begin
                                    mult_w = '{'{w[0][3:2], w[0][1:0]}, 
                                               '{w[1][3:2], w[1][1:0]}};
                                    mult_a = '{'{a[0][1:0], a[1][1:0]}, 
                                               '{a[0][3:2], a[1][3:2]}};
                                    out_tmp = $unsigned(mult_z[0][0]) + $unsigned(mult_z[0][1]) + $unsigned(mult_z[1][0]) + $unsigned(mult_z[1][1]);
                                end
                            end
                        endcase
                    end
                endcase
            end
            1'b1: begin: DVAFS_ON
                case(BG)
                    1'b0: begin: BG_MAC
                        always_comb begin
                        mult_w = '{'{w[0][3:2],         w[0][1:0] & ~prec}, 
                                   '{w[0][3:2] & ~prec, w[0][1:0]}};
                        mult_a = '{'{a[0][1:0],         a[0][1:0] & ~prec}, 
                                   '{a[0][3:2] & ~prec, a[0][3:2]}};
                        end
                        case(MODE)
                            2'b00: begin: SA
                                always_comb begin
                                    unique case(prec)
                                        2'b00: // 4b*4b
                                            out_tmp = $unsigned({mult_z[0][0], 2'b0}) + $unsigned(mult_z[0][1]) + $unsigned({mult_z[1][0], 4'b0}) + $unsigned({mult_z[1][1], 2'b0});
                                        2'b11: begin // 2b*2b
                                            out_tmp [7:4]   = mult_z[0][0];
                                            out_tmp [3:0]   = mult_z[1][1];
                                        end
                                    endcase
                                end
                            end
                            
                            2'b11: begin: ST
                                always_comb begin
                                    unique case(prec)
                                        2'b00: // 4b*4b
                                            out_tmp = $unsigned({mult_z[0][0], 2'b0}) + $unsigned(mult_z[0][1]) + $unsigned({mult_z[1][0], 4'b0}) + $unsigned({mult_z[1][1], 2'b0});
                                        2'b11: // 2b*2b
                                            out_tmp = $unsigned(mult_z[0][0]) + $unsigned(mult_z[1][1]);
                                    endcase
                                end
                            end
                        endcase
                    end
                    
                    1'b1: begin: BG_ARR
                        always_comb begin
                        mult_w = '{'{w[0][3:2], 2'b00}, 
                                   '{2'b00,     w[0][1:0]}};
                        mult_a = '{'{a[0][1:0], 2'b00}, 
                                   '{2'b00,     a[0][3:2]}};
                        end
                        case(MODE)
                            2'b00: begin: SA
                                always_comb begin
                                    out_tmp [7:4]   = mult_z[0][0];
                                    out_tmp [3:0]   = mult_z[1][1];
                                end
                            end
                            
                            2'b11: begin: ST
                                always_comb begin
                                    out_tmp = $unsigned(mult_z[0][0]) + $unsigned(mult_z[1][1]);
                                end
                            end
                        endcase
                    end
                endcase
            end
        endcase
    endgenerate
    
endmodule