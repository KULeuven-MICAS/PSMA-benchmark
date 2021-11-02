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
// File Name: pb_L2_mac.sv
// Design:    pb_L2
// Function:  Powerbench for L2_mac
//-----------------------------------------------------

`timescale 1ns/1ps

module pb_L2 ();

    //-------------Parameters------------------------------
    parameter            TEST     = 1'b1;
    parameter            PRCSN    = 4'b0000;
    parameter            CLK_PRD  = 2.5ns;
    parameter            VCD_FILE = $sformatf("dump_%4b_clk%3.2f.vcd",PRCSN,CLK_PRD);
    
    parameter            HEADROOM = 4;
    parameter            MODE     = 4'b0000;    // Determines if in/out are shared for x/y dimensions
                                                // 0: input shared, 1: output shared
                                                // MODE[3:2] -> L2_mac, MODE[1:0] -> L1_mult
    parameter            BG       = 2'b00;      // Bitgroups (0: unroll in MAC, 1: unroll out of MAC)
    parameter            DVAFS    = 1'b0;
    
    //-------------Local parameters------------------------
    localparam           HELP_MODE   = (BG[1]) ? 4'b1111 : MODE;
    localparam           A_INPUTS    = helper::get_L2_A_inputs(DVAFS, HELP_MODE);              // No. of A and W inputs is 1 if SA, 
    localparam           W_INPUTS    = helper::get_L2_W_inputs(DVAFS, HELP_MODE);              // 4 if ST, 2 if SA/ST
    localparam           MAX_OUTPUTS = helper::get_L2_max_out(DVAFS, HELP_MODE);               // Max. number of outputs in each MODE
    localparam           MULT_WIDTH  = helper::get_L2_out_width(DVAFS, BG, HELP_MODE);   // Width of the 8x8 multiplication (without accumulation)
                                                                                            // See function definitions at helper package
                                                                                                        
    localparam           Z_WIDTH     = (BG[1]) ? MULT_WIDTH + 12 : MULT_WIDTH + (MAX_OUTPUTS * HEADROOM);
    
    localparam           MZ          = Z_WIDTH / 2;        // Mid-Point of z 
    localparam           QZ          = Z_WIDTH / 4;        // Quarter-Point of z 
    localparam           TZ          = 3*Z_WIDTH / 4;      // Three-Quarters-Point of z 
    localparam           MM          = MULT_WIDTH / 2;     // Mid-Point of mult 
    localparam           QM          = MULT_WIDTH / 4;     // Quarter-Point of mult
    localparam           TM          = 3*MULT_WIDTH / 4;   // Three-Quarters-Point of mult
    localparam           H           = HEADROOM;           // Shorthand for headroom
    
    // Logic for top_L2_mac module
    logic                clk, rst; 
    logic [7:0]          a [A_INPUTS];
    logic [7:0]          w [W_INPUTS];
    logic [Z_WIDTH-1:0]  z;
    logic [3:0]          prec;
    
    // Expected Results
    logic [((BG[1]) ? 31 : MULT_WIDTH-1):0] mult_exp;
    logic [((BG[1]) ? 31 : Z_WIDTH-1):0]    accum;

    // Logic for bit_serial design
    logic                accum_en;
    logic [7:0]          a_full [4][4];
    logic [7:0]          w_full [4][4]; 
    int                  prec_w, prec_a, clk_to_out; 

    //-------------UUT Instantiation-----------------------
    generate
        if(A_INPUTS==1) begin
            top_L2_mac L2 (
                clk, rst, prec, a[0], w[0] , z
            );
        end
        else if(A_INPUTS==2 && W_INPUTS==1) begin
            top_L2_mac L2 (
                clk, rst, prec, a[1], a[0], w[0] , z
            );
        end
        else if(A_INPUTS==2 && W_INPUTS==2) begin
            top_L2_mac L2 (
                clk, rst, prec, a[1], a[0], w[1], w[0] , z
            );
        end
        else if(A_INPUTS==4 && W_INPUTS==1) begin
            top_L2_mac L2 (
                clk, rst, prec, a[3], a[2], a[1], a[0], w[0] , z
            );
        end
        else if(A_INPUTS==4 && W_INPUTS==2) begin
            top_L2_mac L2 (
                clk, rst, prec, a[3], a[2], a[1], a[0], w[1], w[0] , z
            );
        end
        else if(A_INPUTS==4 && W_INPUTS==4) begin
            top_L2_mac L2 (
                clk, rst, prec, a[3], a[2], a[1], a[0], w[3] , w[2] , w[1] , w[0] , z
            );
        end
    endgenerate

    // Set prec_a, prec_w, and # clks to out for bit_serial
    always_comb begin
        case(prec)
            4'b0000: begin
                prec_a = 8;
                prec_w = 8;
            end
            4'b0010: begin
                prec_a = 4;
                prec_w = 8;
            end
            4'b0011: begin
                prec_a = 2;
                prec_w = 8;
            end
            4'b1010: begin
                prec_a = 4;
                prec_w = 4;
            end
            4'b1111: begin
                prec_a = 2;
                prec_w = 2;
            end
        endcase
        clk_to_out = (prec_a/2) * (prec_w/2);
    end
    
    //-------------Clock-----------------------------------
    initial clk = 0;
    always #(CLK_PRD/2) clk = ~clk;
    
    // Bench for spatial unrolling
    task bench_spatial(input bit [3:0] precision);
        // initial reset
        rst  =  1;
        $assertoff;
        a    = '{default:0};
        w    = '{default:0};
        // prec = 4'b0000;
        repeat (5) @(negedge clk);
        prec = precision;
        if(!TEST) begin
            $dumpfile(VCD_FILE);
            $dumpvars(0, genblk1.L2);
        end
        repeat (2) @(negedge clk) begin
            // reset
            rst      =  1;
            $assertoff;
            $assertkill;
            repeat (2) @(negedge clk);
            rst      =  0;
            $asserton;
            repeat (256) begin
                void'(randomize(a));
                void'(randomize(w));
                @(negedge clk);
            end
        end
    endtask

    // Bench for temporal unrolling
    task bench_temporal(input bit [3:0] precision);
        // initial reset
        rst    =  1;
        $assertoff;
        $assertkill;
        a_full = '{default:0};
        w_full = '{default:0};
        prec = 4'b0000;
        repeat (5) @(negedge clk);
        prec = precision;
        if(!TEST) begin
            $dumpfile(VCD_FILE);
            $dumpvars(0, genblk1.L2);
        end
        repeat (2) @(negedge clk) begin
            // reset
            rst      =  1;
            $assertoff;
            $assertkill;
            repeat (2) @(negedge clk);
            rst      =  0;
            $asserton;
            repeat (256/clk_to_out) begin
                accum_en = 1; 
                foreach(a_full[i,j]) a_full[i][j] = $urandom()%255 >> (8-prec_a);
                foreach(w_full[i,j]) w_full[i][j] = $urandom()%255 >> (8-prec_w);
                for(int i = 0; i < prec_w; i = i+2) begin
                    for(int j = 0; j < prec_a; j = j+2) begin
                        a[0] = {a_full[3][0][j+:2], a_full[2][0][j+:2], a_full[1][0][j+:2], a_full[0][0][j+:2]};
                        a[1] = {a_full[3][2][j+:2], a_full[2][2][j+:2], a_full[1][2][j+:2], a_full[0][2][j+:2]};
                        a[2] = {a_full[3][1][j+:2], a_full[2][1][j+:2], a_full[1][1][j+:2], a_full[0][1][j+:2]};
                        a[3] = {a_full[3][3][j+:2], a_full[2][3][j+:2], a_full[1][3][j+:2], a_full[0][3][j+:2]};
                        
                        w[0] = {w_full[0][0][i+:2], w_full[0][1][i+:2], w_full[0][2][i+:2], w_full[0][3][i+:2]};
                        w[1] = {w_full[2][0][i+:2], w_full[2][1][i+:2], w_full[2][2][i+:2], w_full[2][3][i+:2]};
                        w[2] = {w_full[1][0][i+:2], w_full[1][1][i+:2], w_full[1][2][i+:2], w_full[1][3][i+:2]};
                        w[3] = {w_full[3][0][i+:2], w_full[3][1][i+:2], w_full[3][2][i+:2], w_full[3][3][i+:2]};
                        
                        @(negedge clk); 
                        accum_en = 0; 
                    end
                end
            end
        end
    endtask
    
    // Actual Bench execution
    initial begin
        case(BG[1])
            1'b0: begin: SPATIAL
                if(TEST) begin
                    if(!BG[0]) begin
                        bench_spatial(4'b0000);      // 8bx8b
                        if(!DVAFS) begin 
                            bench_spatial(4'b0010);  // 8bx4b
                            bench_spatial(4'b0011);  // 8bx2b
                        end
                        bench_spatial(4'b1010);      // 4bx4b
                    end
                    bench_spatial(4'b1111);          // 2bx2b
                end
                else bench_spatial(PRCSN);
            end
            1'b1: begin: TEMPORAL
                if(TEST) begin
                    bench_temporal(4'b0000); 
                    bench_temporal(4'b0010); 
                    bench_temporal(4'b0011); 
                    bench_temporal(4'b1010); 
                    bench_temporal(4'b1111); 
                end
                else bench_temporal(PRCSN);
            end
        endcase
        $stop;
    end
    
    // Expected Multiplication
    always_comb begin
        case(DVAFS)
            1'b0: begin
                case(BG)
                    2'b00: begin
                        case(prec)
                            4'b0000: begin    // 8bx8b
                                mult_exp = $unsigned(a[0]) * $unsigned(w[0]);
                            end
                            4'b0010: begin    // 8bx4b
                                case(MODE[3])
                                    1'b0: begin
                                        mult_exp[(2 *MM)-1 -: MM] = $unsigned(a[0]) * $unsigned(w[0][7:4]);
                                        mult_exp[(1 *MM)-1 -: MM] = $unsigned(a[0]) * $unsigned(w[0][3:0]);
                                    end
                                    1'b1: begin
                                        mult_exp = ($unsigned(a[0]) * $unsigned(w[0][7:4])) + ($unsigned(a[1]) * $unsigned(w[0][3:0]));
                                    end
                                endcase
                            end
                            4'b0011: begin   // 8bx2b
                                case({MODE[3], MODE[1]})
                                    2'b00: begin
                                        mult_exp[(4 *QM)-1 -: QM] = $unsigned(a[0]) * $unsigned(w[0][7:6]);
                                        mult_exp[(3 *QM)-1 -: QM] = $unsigned(a[0]) * $unsigned(w[0][5:4]);
                                        mult_exp[(2 *QM)-1 -: QM] = $unsigned(a[0]) * $unsigned(w[0][3:2]);
                                        mult_exp[(1 *QM)-1 -: QM] = $unsigned(a[0]) * $unsigned(w[0][1:0]);
                                    end
                                    2'b01: begin
                                        mult_exp[(2 *MM)-1 -: MM] = ($unsigned(a[0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1]) * $unsigned(w[0][5:4]));
                                        mult_exp[(1 *MM)-1 -: MM] = ($unsigned(a[0]) * $unsigned(w[0][3:2])) + ($unsigned(a[1]) * $unsigned(w[0][1:0]));
                                    end
                                    2'b10: begin
                                        mult_exp[(2 *MM)-1 -: MM] = ($unsigned(a[0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1]) * $unsigned(w[0][3:2]));
                                        mult_exp[(1 *MM)-1 -: MM] = ($unsigned(a[0]) * $unsigned(w[0][5:4])) + ($unsigned(a[1]) * $unsigned(w[0][1:0]));
                                    end
                                    2'b11: begin
                                        mult_exp = ($unsigned(a[0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1]) * $unsigned(w[0][3:2]))
                                                + ($unsigned(a[2]) * $unsigned(w[0][5:4])) + ($unsigned(a[3]) * $unsigned(w[0][1:0]));
                                    end
                                endcase
                            end
                            4'b1010: begin   // 4bx4b
                                case({MODE[3], MODE[2]})
                                    2'b00: begin
                                        mult_exp[(4 *QM)-1 -: QM] = $unsigned(a[0][3:0]) * $unsigned(w[0][7:4]);
                                        mult_exp[(3 *QM)-1 -: QM] = $unsigned(a[0][3:0]) * $unsigned(w[0][3:0]);
                                        mult_exp[(2 *QM)-1 -: QM] = $unsigned(a[0][7:4]) * $unsigned(w[0][7:4]);
                                        mult_exp[(1 *QM)-1 -: QM] = $unsigned(a[0][7:4]) * $unsigned(w[0][3:0]);
                                    end
                                    2'b10: begin
                                        mult_exp[(2 *MM)-1 -: MM] = ($unsigned(a[0][3:0]) * $unsigned(w[0][7:4])) + ($unsigned(a[1][3:0]) * $unsigned(w[0][3:0]));
                                        mult_exp[(1 *MM)-1 -: MM] = ($unsigned(a[0][7:4]) * $unsigned(w[0][7:4])) + ($unsigned(a[1][7:4]) * $unsigned(w[0][3:0]));
                                    end
                                    2'b11: begin
                                        mult_exp = ($unsigned(a[0][3:0]) * $unsigned(w[0][7:4])) + ($unsigned(a[1][3:0]) * $unsigned(w[0][3:0]))
                                                + ($unsigned(a[0][7:4]) * $unsigned(w[1][7:4])) + ($unsigned(a[1][7:4]) * $unsigned(w[1][3:0]));
                                    end
                                endcase
                            end
                            4'b1111: begin   // 2bx2b
                                case(MODE)
                                    4'b0000: begin
                                        mult_exp[(16*4)-1 -: 4]   = $unsigned(a[0][1:0]) * $unsigned(w[0][7:6]);
                                        mult_exp[(15*4)-1 -: 4]   = $unsigned(a[0][1:0]) * $unsigned(w[0][5:4]);
                                        mult_exp[(14*4)-1 -: 4]   = $unsigned(a[0][3:2]) * $unsigned(w[0][7:6]);
                                        mult_exp[(13*4)-1 -: 4]   = $unsigned(a[0][3:2]) * $unsigned(w[0][5:4]);
                                        
                                        mult_exp[(12*4)-1 -: 4]   = $unsigned(a[0][1:0]) * $unsigned(w[0][3:2]);
                                        mult_exp[(11*4)-1 -: 4]   = $unsigned(a[0][1:0]) * $unsigned(w[0][1:0]);
                                        mult_exp[(10*4)-1 -: 4]   = $unsigned(a[0][3:2]) * $unsigned(w[0][3:2]);
                                        mult_exp[(9 *4)-1 -: 4]   = $unsigned(a[0][3:2]) * $unsigned(w[0][1:0]);
                                        
                                        mult_exp[(8 *4)-1 -: 4]   = $unsigned(a[0][5:4]) * $unsigned(w[0][7:6]);
                                        mult_exp[(7 *4)-1 -: 4]   = $unsigned(a[0][5:4]) * $unsigned(w[0][5:4]);
                                        mult_exp[(6 *4)-1 -: 4]   = $unsigned(a[0][7:6]) * $unsigned(w[0][7:6]);
                                        mult_exp[(5 *4)-1 -: 4]   = $unsigned(a[0][7:6]) * $unsigned(w[0][5:4]);
                                        
                                        mult_exp[(4 *4)-1 -: 4]   = $unsigned(a[0][5:4]) * $unsigned(w[0][3:2]);
                                        mult_exp[(3 *4)-1 -: 4]   = $unsigned(a[0][5:4]) * $unsigned(w[0][1:0]);
                                        mult_exp[(2 *4)-1 -: 4]   = $unsigned(a[0][7:6]) * $unsigned(w[0][3:2]);
                                        mult_exp[(1 *4)-1 -: 4]   = $unsigned(a[0][7:6]) * $unsigned(w[0][1:0]);
                                    end
                                    4'b0010: begin
                                        mult_exp[(8 *5)-1 -: 5]   = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][5:4]));
                                        mult_exp[(7 *5)-1 -: 5]   = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][5:4]));
                                        mult_exp[(6 *5)-1 -: 5]   = ($unsigned(a[0][1:0]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][1:0]));
                                        mult_exp[(5 *5)-1 -: 5]   = ($unsigned(a[0][3:2]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][1:0]));
                                        
                                        mult_exp[(4 *5)-1 -: 5]   = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][5:4]));
                                        mult_exp[(3 *5)-1 -: 5]   = ($unsigned(a[0][7:6]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][5:4])); 
                                        mult_exp[(2 *5)-1 -: 5]   = ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][1:0]));
                                        mult_exp[(1 *5)-1 -: 5]   = ($unsigned(a[0][7:6]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][1:0]));
                                    end
                                    4'b0011: begin
                                        mult_exp[(4 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][5:4]))
                                                                + ($unsigned(a[0][3:2]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[1][5:4]));
                                        mult_exp[(3 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][1:0]))
                                                                + ($unsigned(a[0][3:2]) * $unsigned(w[1][3:2])) + ($unsigned(a[1][3:2]) * $unsigned(w[1][1:0]));
                                        mult_exp[(2 *QM)-1 -: QM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][5:4]))
                                                                + ($unsigned(a[0][7:6]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][5:4])); 
                                        mult_exp[(1 *QM)-1 -: QM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][1:0]))
                                                                + ($unsigned(a[0][7:6]) * $unsigned(w[1][3:2])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][1:0]));
                                    end
                                    4'b1000: begin
                                        mult_exp[(8 *5)-1 -: 5]   = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]));
                                        mult_exp[(7 *5)-1 -: 5]   = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][3:2]));
                                        mult_exp[(6 *5)-1 -: 5]   = ($unsigned(a[0][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][1:0]));
                                        mult_exp[(5 *5)-1 -: 5]   = ($unsigned(a[0][5:4]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][1:0]));
                                        
                                        mult_exp[(4 *5)-1 -: 5]   = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][3:2]));
                                        mult_exp[(3 *5)-1 -: 5]   = ($unsigned(a[0][7:6]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][3:2])); 
                                        mult_exp[(2 *5)-1 -: 5]   = ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][1:0])); 
                                        mult_exp[(1 *5)-1 -: 5]   = ($unsigned(a[0][7:6]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][1:0])); 
                                    end
                                    4'b1010: begin
                                        mult_exp[(4 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[2][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][1:0]) * $unsigned(w[0][1:0]));
                                        mult_exp[(3 *QM)-1 -: QM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[2][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][3:2]) * $unsigned(w[0][1:0]));
                                        
                                        mult_exp[(2 *QM)-1 -: QM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[2][5:4]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][5:4]) * $unsigned(w[0][1:0]));
                                        mult_exp[(1 *QM)-1 -: QM] = ($unsigned(a[0][7:6]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[2][7:6]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][7:6]) * $unsigned(w[0][1:0]));
                                    end
                                    4'b1011: begin
                                        mult_exp[(2 *MM)-1 -: MM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[2][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][1:0]) * $unsigned(w[0][1:0]))
                                                                + ($unsigned(a[0][3:2]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[1][3:2]))
                                                                + ($unsigned(a[2][3:2]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][3:2]) * $unsigned(w[1][1:0]));
                                        
                                        mult_exp[(1 *MM)-1 -: MM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[2][5:4]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][5:4]) * $unsigned(w[0][1:0]))
                                                                + ($unsigned(a[0][7:6]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][3:2]))
                                                                + ($unsigned(a[2][7:6]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][7:6]) * $unsigned(w[1][1:0]));
                                    end
                                    4'b1100: begin
                                        mult_exp[(4 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[0][5:4]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[1][3:2]));
                                        mult_exp[(3 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][1:0]))
                                                                + ($unsigned(a[0][5:4]) * $unsigned(w[1][5:4])) + ($unsigned(a[1][5:4]) * $unsigned(w[1][1:0]));
                                        
                                        mult_exp[(2 *QM)-1 -: QM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[0][7:6]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][3:2]));
                                        mult_exp[(1 *QM)-1 -: QM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][1:0]))
                                                                + ($unsigned(a[0][7:6]) * $unsigned(w[1][5:4])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][1:0]));
                                    end
                                    4'b1110: begin
                                        mult_exp[(2 *MM)-1 -: MM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[2][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][1:0]) * $unsigned(w[0][1:0]))
                                                                + ($unsigned(a[0][5:4]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[1][3:2]))
                                                                + ($unsigned(a[2][5:4]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][5:4]) * $unsigned(w[1][1:0]));
                                        
                                        mult_exp[(1 *MM)-1 -: MM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][3:2]))
                                                                + ($unsigned(a[2][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][3:2]) * $unsigned(w[0][1:0]))
                                                                + ($unsigned(a[0][7:6]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][3:2]))
                                                                + ($unsigned(a[2][7:6]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][7:6]) * $unsigned(w[1][1:0]));
                                    end
                                    4'b1111: begin
                                        mult_exp = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                                + ($unsigned(a[2][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][1:0]) * $unsigned(w[0][1:0]))
                                                + ($unsigned(a[0][5:4]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[1][3:2]))
                                                + ($unsigned(a[2][5:4]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][5:4]) * $unsigned(w[1][1:0]))
                                                + ($unsigned(a[0][3:2]) * $unsigned(w[2][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[2][3:2]))
                                                + ($unsigned(a[2][3:2]) * $unsigned(w[2][5:4])) + ($unsigned(a[3][3:2]) * $unsigned(w[2][1:0]))
                                                + ($unsigned(a[0][7:6]) * $unsigned(w[3][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[3][3:2]))
                                                + ($unsigned(a[2][7:6]) * $unsigned(w[3][5:4])) + ($unsigned(a[3][7:6]) * $unsigned(w[3][1:0]));
                                    end
                                endcase
                            end
                        endcase
                    end
                    2'b01: begin
                        case(MODE)
                            4'b0000: begin
                                mult_exp[(16*4)-1 -: 4]   = $unsigned(a[0][1:0]) * $unsigned(w[0][7:6]);
                                mult_exp[(15*4)-1 -: 4]   = $unsigned(a[0][1:0]) * $unsigned(w[0][5:4]);
                                mult_exp[(14*4)-1 -: 4]   = $unsigned(a[0][3:2]) * $unsigned(w[0][7:6]);
                                mult_exp[(13*4)-1 -: 4]   = $unsigned(a[0][3:2]) * $unsigned(w[0][5:4]);
                                
                                mult_exp[(12*4)-1 -: 4]   = $unsigned(a[0][1:0]) * $unsigned(w[0][3:2]);
                                mult_exp[(11*4)-1 -: 4]   = $unsigned(a[0][1:0]) * $unsigned(w[0][1:0]);
                                mult_exp[(10*4)-1 -: 4]   = $unsigned(a[0][3:2]) * $unsigned(w[0][3:2]);
                                mult_exp[(9 *4)-1 -: 4]   = $unsigned(a[0][3:2]) * $unsigned(w[0][1:0]);
                                
                                mult_exp[(8 *4)-1 -: 4]   = $unsigned(a[0][5:4]) * $unsigned(w[0][7:6]);
                                mult_exp[(7 *4)-1 -: 4]   = $unsigned(a[0][5:4]) * $unsigned(w[0][5:4]);
                                mult_exp[(6 *4)-1 -: 4]   = $unsigned(a[0][7:6]) * $unsigned(w[0][7:6]);
                                mult_exp[(5 *4)-1 -: 4]   = $unsigned(a[0][7:6]) * $unsigned(w[0][5:4]);
                                
                                mult_exp[(4 *4)-1 -: 4]   = $unsigned(a[0][5:4]) * $unsigned(w[0][3:2]);
                                mult_exp[(3 *4)-1 -: 4]   = $unsigned(a[0][5:4]) * $unsigned(w[0][1:0]);
                                mult_exp[(2 *4)-1 -: 4]   = $unsigned(a[0][7:6]) * $unsigned(w[0][3:2]);
                                mult_exp[(1 *4)-1 -: 4]   = $unsigned(a[0][7:6]) * $unsigned(w[0][1:0]);
                            end
                            4'b0010: begin
                                mult_exp[(8 *5)-1 -: 5]   = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][5:4]));
                                mult_exp[(7 *5)-1 -: 5]   = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][5:4]));
                                mult_exp[(6 *5)-1 -: 5]   = ($unsigned(a[0][1:0]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][1:0]));
                                mult_exp[(5 *5)-1 -: 5]   = ($unsigned(a[0][3:2]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][1:0]));
                                
                                mult_exp[(4 *5)-1 -: 5]   = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][5:4]));
                                mult_exp[(3 *5)-1 -: 5]   = ($unsigned(a[0][7:6]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][5:4])); 
                                mult_exp[(2 *5)-1 -: 5]   = ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][1:0]));
                                mult_exp[(1 *5)-1 -: 5]   = ($unsigned(a[0][7:6]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][1:0]));
                            end
                            4'b0011: begin
                                mult_exp[(4 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][5:4]))
                                                            + ($unsigned(a[0][3:2]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[1][5:4]));
                                mult_exp[(3 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][1:0]))
                                                            + ($unsigned(a[0][3:2]) * $unsigned(w[1][3:2])) + ($unsigned(a[1][3:2]) * $unsigned(w[1][1:0]));
                                mult_exp[(2 *QM)-1 -: QM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][5:4]))
                                                            + ($unsigned(a[0][7:6]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][5:4])); 
                                mult_exp[(1 *QM)-1 -: QM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][1:0]))
                                                            + ($unsigned(a[0][7:6]) * $unsigned(w[1][3:2])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][1:0]));
                            end
                            4'b1000: begin
                                mult_exp[(8 *5)-1 -: 5]   = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]));
                                mult_exp[(7 *5)-1 -: 5]   = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][3:2]));
                                mult_exp[(6 *5)-1 -: 5]   = ($unsigned(a[0][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][1:0]));
                                mult_exp[(5 *5)-1 -: 5]   = ($unsigned(a[0][5:4]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][1:0]));
                                
                                mult_exp[(4 *5)-1 -: 5]   = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][3:2]));
                                mult_exp[(3 *5)-1 -: 5]   = ($unsigned(a[0][7:6]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][3:2])); 
                                mult_exp[(2 *5)-1 -: 5]   = ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][1:0])); 
                                mult_exp[(1 *5)-1 -: 5]   = ($unsigned(a[0][7:6]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][1:0])); 
                            end
                            4'b1010: begin
                                mult_exp[(4 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[2][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][1:0]) * $unsigned(w[0][1:0]));
                                mult_exp[(3 *QM)-1 -: QM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[2][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][3:2]) * $unsigned(w[0][1:0]));
                                
                                mult_exp[(2 *QM)-1 -: QM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[2][5:4]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][5:4]) * $unsigned(w[0][1:0]));
                                mult_exp[(1 *QM)-1 -: QM] = ($unsigned(a[0][7:6]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[2][7:6]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][7:6]) * $unsigned(w[0][1:0]));
                            end
                            4'b1011: begin
                                mult_exp[(2 *MM)-1 -: MM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[2][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][1:0]) * $unsigned(w[0][1:0]))
                                                            + ($unsigned(a[0][3:2]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[1][3:2]))
                                                            + ($unsigned(a[2][3:2]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][3:2]) * $unsigned(w[1][1:0]));
                                
                                mult_exp[(1 *MM)-1 -: MM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[2][5:4]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][5:4]) * $unsigned(w[0][1:0]))
                                                            + ($unsigned(a[0][7:6]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][3:2]))
                                                            + ($unsigned(a[2][7:6]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][7:6]) * $unsigned(w[1][1:0]));
                            end
                            4'b1100: begin
                                mult_exp[(4 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[0][5:4]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[1][3:2]));
                                mult_exp[(3 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][1:0]))
                                                            + ($unsigned(a[0][5:4]) * $unsigned(w[1][5:4])) + ($unsigned(a[1][5:4]) * $unsigned(w[1][1:0]));
                                
                                mult_exp[(2 *QM)-1 -: QM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[0][7:6]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][3:2]));
                                mult_exp[(1 *QM)-1 -: QM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][1:0]))
                                                            + ($unsigned(a[0][7:6]) * $unsigned(w[1][5:4])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][1:0]));
                            end
                            4'b1110: begin
                                mult_exp[(2 *MM)-1 -: MM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[2][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][1:0]) * $unsigned(w[0][1:0]))
                                                            + ($unsigned(a[0][5:4]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[1][3:2]))
                                                            + ($unsigned(a[2][5:4]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][5:4]) * $unsigned(w[1][1:0]));
                                
                                mult_exp[(1 *MM)-1 -: MM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[0][3:2]))
                                                            + ($unsigned(a[2][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][3:2]) * $unsigned(w[0][1:0]))
                                                            + ($unsigned(a[0][7:6]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[1][3:2]))
                                                            + ($unsigned(a[2][7:6]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][7:6]) * $unsigned(w[1][1:0]));
                            end
                            4'b1111: begin
                                mult_exp = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[1][1:0]) * $unsigned(w[0][3:2]))
                                            + ($unsigned(a[2][1:0]) * $unsigned(w[0][5:4])) + ($unsigned(a[3][1:0]) * $unsigned(w[0][1:0]))
                                            + ($unsigned(a[0][5:4]) * $unsigned(w[1][7:6])) + ($unsigned(a[1][5:4]) * $unsigned(w[1][3:2]))
                                            + ($unsigned(a[2][5:4]) * $unsigned(w[1][5:4])) + ($unsigned(a[3][5:4]) * $unsigned(w[1][1:0]))
                                            + ($unsigned(a[0][3:2]) * $unsigned(w[2][7:6])) + ($unsigned(a[1][3:2]) * $unsigned(w[2][3:2]))
                                            + ($unsigned(a[2][3:2]) * $unsigned(w[2][5:4])) + ($unsigned(a[3][3:2]) * $unsigned(w[2][1:0]))
                                            + ($unsigned(a[0][7:6]) * $unsigned(w[3][7:6])) + ($unsigned(a[1][7:6]) * $unsigned(w[3][3:2]))
                                            + ($unsigned(a[2][7:6]) * $unsigned(w[3][5:4])) + ($unsigned(a[3][7:6]) * $unsigned(w[3][1:0]));
                            end
                        endcase
                    end
                    2'b11: begin
                        mult_exp = (a_full[0][0] * w_full[0][0]) + (a_full[0][1] * w_full[0][1]) + (a_full[0][2] * w_full[0][2]) + (a_full[0][3] * w_full[0][3]) + 
                                   (a_full[1][0] * w_full[1][0]) + (a_full[1][1] * w_full[1][1]) + (a_full[1][2] * w_full[1][2]) + (a_full[1][3] * w_full[1][3]) + 
                                   (a_full[2][0] * w_full[2][0]) + (a_full[2][1] * w_full[2][1]) + (a_full[2][2] * w_full[2][2]) + (a_full[2][3] * w_full[2][3]) + 
                                   (a_full[3][0] * w_full[3][0]) + (a_full[3][1] * w_full[3][1]) + (a_full[3][2] * w_full[3][2]) + (a_full[3][3] * w_full[3][3]);
                    end
                endcase
            end
            
            
            1'b1: begin
                case(BG)
                    2'b00: begin
                        case(prec)
                            4'b0000: begin    // 8bx8b
                                mult_exp = $unsigned(a[0]) * $unsigned(w[0]);
                            end
                            4'b1010: begin   // 4bx4b
                                case({MODE[3], MODE[2]})
                                    2'b00: begin
                                        mult_exp[(2 *MM)-1 -: MM] = $unsigned(a[0][3:0]) * $unsigned(w[0][7:4]);
                                        mult_exp[(1 *MM)-1 -: MM] = $unsigned(a[0][7:4]) * $unsigned(w[0][3:0]);
                                    end
                                    2'b11: begin
                                        mult_exp = ($unsigned(a[0][3:0]) * $unsigned(w[0][7:4])) + ($unsigned(a[0][7:4]) * $unsigned(w[0][3:0]));
                                    end
                                endcase
                            end
                            4'b1111: begin   // 2bx2b
                                case(MODE)
                                    4'b0000: begin
                                        mult_exp[(4 *QM)-1 -: QM] = $unsigned(a[0][1:0]) * $unsigned(w[0][7:6]);
                                        mult_exp[(3 *QM)-1 -: QM] = $unsigned(a[0][3:2]) * $unsigned(w[0][5:4]);
                                        mult_exp[(2 *QM)-1 -: QM] = $unsigned(a[0][5:4]) * $unsigned(w[0][3:2]); 
                                        mult_exp[(1 *QM)-1 -: QM] = $unsigned(a[0][7:6]) * $unsigned(w[0][1:0]);
                                    end
                                    4'b0011: begin
                                        mult_exp[(2 *MM)-1 -: MM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4])); 
                                        mult_exp[(1 *MM)-1 -: MM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])) + ($unsigned(a[0][7:6]) * $unsigned(w[0][1:0]));
                                    end
                                    4'b1100: begin
                                        mult_exp[(2 *MM)-1 -: MM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])); 
                                        mult_exp[(1 *MM)-1 -: MM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[0][7:6]) * $unsigned(w[0][1:0]));
                                    end
                                    4'b1111: begin
                                        mult_exp = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4]))
                                                 + ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])) + ($unsigned(a[0][7:6]) * $unsigned(w[0][1:0]));
                                    end
                                endcase
                            end
                        endcase
                    end
                    2'b01: begin
                        case(MODE)
                            4'b0000: begin
                                mult_exp[(4 *QM)-1 -: QM] = $unsigned(a[0][1:0]) * $unsigned(w[0][7:6]);
                                mult_exp[(3 *QM)-1 -: QM] = $unsigned(a[0][3:2]) * $unsigned(w[0][5:4]);
                                mult_exp[(2 *QM)-1 -: QM] = $unsigned(a[0][5:4]) * $unsigned(w[0][3:2]); 
                                mult_exp[(1 *QM)-1 -: QM] = $unsigned(a[0][7:6]) * $unsigned(w[0][1:0]);
                            end
                            4'b0011: begin
                                mult_exp[(2 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4])); 
                                mult_exp[(1 *QM)-1 -: QM] = ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])) + ($unsigned(a[0][7:6]) * $unsigned(w[0][1:0]));
                            end
                            4'b1100: begin
                                mult_exp[(2 *QM)-1 -: QM] = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])); 
                                mult_exp[(1 *QM)-1 -: QM] = ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4])) + ($unsigned(a[0][7:6]) * $unsigned(w[0][1:0]));
                            end
                            4'b1111: begin
                                mult_exp = ($unsigned(a[0][1:0]) * $unsigned(w[0][7:6])) + ($unsigned(a[0][3:2]) * $unsigned(w[0][5:4]))
                                         + ($unsigned(a[0][5:4]) * $unsigned(w[0][3:2])) + ($unsigned(a[0][7:6]) * $unsigned(w[0][1:0]));
                            end
                        endcase
                    end
                    2'b11: begin
                        //BOOKMARK: Edit Temporal DVAFS design
                    end
                endcase
            end
        endcase
    end
    
    // Expected Accumulation
    always @(posedge clk) begin
        case(DVAFS)
            1'b0: begin
                case(BG)
                    2'b00: begin
                        if (rst) accum <= '0;
                        else case(prec)
                            4'b0000: begin    // 8bx8b
                                accum <= $unsigned(accum) + $unsigned(mult_exp);
                            end
                            4'b0010: begin    // 8bx4b
                                case(MODE[3])
                                    1'b0: begin
                                        accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                        accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                                    end
                                    1'b1: begin
                                        accum <= $unsigned(accum) + $unsigned(mult_exp);
                                    end
                                endcase
                            end
                            4'b0011: begin   // 8bx2b
                                case({MODE[3], MODE[1]})
                                    2'b00: begin
                                        accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                        accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                        accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                        accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                                    end
                                    2'b01: begin
                                        accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                        accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                                    end
                                    2'b10: begin
                                        accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                        accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                                    end
                                    2'b11: begin
                                        accum <= $unsigned(accum) + $unsigned(mult_exp);
                                    end
                                endcase
                            end
                            4'b1010: begin   // 4bx4b
                                case({MODE[3], MODE[2]})
                                    2'b00: begin
                                        accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                        accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                        accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                        accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                                    end
                                    2'b10: begin
                                        accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                        accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                                    end
                                    2'b11: begin
                                        accum <= $unsigned(accum) + $unsigned(mult_exp);
                                    end
                                endcase
                            end
                            4'b1111: begin   // 2bx2b
                                case(MODE)
                                    4'b0000: begin
                                        accum[(16*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(16*4)-1 -: 4]) + $unsigned(accum[(16*(4+H))-1 -: (4+H)]);
                                        accum[(15*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(15*4)-1 -: 4]) + $unsigned(accum[(15*(4+H))-1 -: (4+H)]);
                                        accum[(14*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(14*4)-1 -: 4]) + $unsigned(accum[(14*(4+H))-1 -: (4+H)]);
                                        accum[(13*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(13*4)-1 -: 4]) + $unsigned(accum[(13*(4+H))-1 -: (4+H)]);
                                        
                                        accum[(12*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(12*4)-1 -: 4]) + $unsigned(accum[(12*(4+H))-1 -: (4+H)]);
                                        accum[(11*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(11*4)-1 -: 4]) + $unsigned(accum[(11*(4+H))-1 -: (4+H)]);
                                        accum[(10*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(10*4)-1 -: 4]) + $unsigned(accum[(10*(4+H))-1 -: (4+H)]);
                                        accum[(9 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(9 *4)-1 -: 4]) + $unsigned(accum[(9 *(4+H))-1 -: (4+H)]);
                                        
                                        accum[(8 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(8 *4)-1 -: 4]) + $unsigned(accum[(8 *(4+H))-1 -: (4+H)]);
                                        accum[(7 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(7 *4)-1 -: 4]) + $unsigned(accum[(7 *(4+H))-1 -: (4+H)]);
                                        accum[(6 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(6 *4)-1 -: 4]) + $unsigned(accum[(6 *(4+H))-1 -: (4+H)]);
                                        accum[(5 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(5 *4)-1 -: 4]) + $unsigned(accum[(5 *(4+H))-1 -: (4+H)]);
                                        
                                        accum[(4 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(4 *4)-1 -: 4]) + $unsigned(accum[(4 *(4+H))-1 -: (4+H)]);
                                        accum[(3 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(3 *4)-1 -: 4]) + $unsigned(accum[(3 *(4+H))-1 -: (4+H)]);
                                        accum[(2 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(2 *4)-1 -: 4]) + $unsigned(accum[(2 *(4+H))-1 -: (4+H)]);
                                        accum[(1 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(1 *4)-1 -: 4]) + $unsigned(accum[(1 *(4+H))-1 -: (4+H)]);
                                    end
                                    4'b0010: begin
                                        accum[(8 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(8 *5)-1 -: 5]) + $unsigned(accum[(8 *(5+H))-1 -: (5+H)]);
                                        accum[(7 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(7 *5)-1 -: 5]) + $unsigned(accum[(7 *(5+H))-1 -: (5+H)]);
                                        accum[(6 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(6 *5)-1 -: 5]) + $unsigned(accum[(6 *(5+H))-1 -: (5+H)]);
                                        accum[(5 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(5 *5)-1 -: 5]) + $unsigned(accum[(5 *(5+H))-1 -: (5+H)]);
                                        
                                        accum[(4 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(4 *5)-1 -: 5]) + $unsigned(accum[(4 *(5+H))-1 -: (5+H)]);
                                        accum[(3 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(3 *5)-1 -: 5]) + $unsigned(accum[(3 *(5+H))-1 -: (5+H)]);
                                        accum[(2 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(2 *5)-1 -: 5]) + $unsigned(accum[(2 *(5+H))-1 -: (5+H)]);
                                        accum[(1 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(1 *5)-1 -: 5]) + $unsigned(accum[(1 *(5+H))-1 -: (5+H)]);
                                    end
                                    4'b0011: begin
                                        accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                        accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                        accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                        accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                                    end
                                    4'b1000: begin
                                        accum[(8 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(8 *5)-1 -: 5]) + $unsigned(accum[(8 *(5+H))-1 -: (5+H)]);
                                        accum[(7 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(7 *5)-1 -: 5]) + $unsigned(accum[(7 *(5+H))-1 -: (5+H)]);
                                        accum[(6 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(6 *5)-1 -: 5]) + $unsigned(accum[(6 *(5+H))-1 -: (5+H)]);
                                        accum[(5 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(5 *5)-1 -: 5]) + $unsigned(accum[(5 *(5+H))-1 -: (5+H)]);
                                        
                                        accum[(4 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(4 *5)-1 -: 5]) + $unsigned(accum[(4 *(5+H))-1 -: (5+H)]);
                                        accum[(3 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(3 *5)-1 -: 5]) + $unsigned(accum[(3 *(5+H))-1 -: (5+H)]);
                                        accum[(2 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(2 *5)-1 -: 5]) + $unsigned(accum[(2 *(5+H))-1 -: (5+H)]);
                                        accum[(1 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(1 *5)-1 -: 5]) + $unsigned(accum[(1 *(5+H))-1 -: (5+H)]);
                                    end
                                    4'b1010: begin
                                        accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                        accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                        accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                        accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                                    end
                                    4'b1011: begin
                                        accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                        accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                                    end
                                    4'b1100: begin
                                        accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                        accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                        accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                        accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                                    end
                                    4'b1110: begin
                                        accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                        accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                                    end
                                    4'b1111: begin
                                        accum <= $unsigned(accum) + $unsigned(mult_exp);
                                    end
                                endcase
                            end
                        endcase
                    end
                    2'b01: begin
                        if (rst) accum <= '0;
                        else case(MODE)
                            4'b0000: begin
                                accum[(16*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(16*4)-1 -: 4]) + $unsigned(accum[(16*(4+H))-1 -: (4+H)]);
                                accum[(15*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(15*4)-1 -: 4]) + $unsigned(accum[(15*(4+H))-1 -: (4+H)]);
                                accum[(14*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(14*4)-1 -: 4]) + $unsigned(accum[(14*(4+H))-1 -: (4+H)]);
                                accum[(13*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(13*4)-1 -: 4]) + $unsigned(accum[(13*(4+H))-1 -: (4+H)]);
                                
                                accum[(12*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(12*4)-1 -: 4]) + $unsigned(accum[(12*(4+H))-1 -: (4+H)]);
                                accum[(11*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(11*4)-1 -: 4]) + $unsigned(accum[(11*(4+H))-1 -: (4+H)]);
                                accum[(10*(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(10*4)-1 -: 4]) + $unsigned(accum[(10*(4+H))-1 -: (4+H)]);
                                accum[(9 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(9 *4)-1 -: 4]) + $unsigned(accum[(9 *(4+H))-1 -: (4+H)]);
                                
                                accum[(8 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(8 *4)-1 -: 4]) + $unsigned(accum[(8 *(4+H))-1 -: (4+H)]);
                                accum[(7 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(7 *4)-1 -: 4]) + $unsigned(accum[(7 *(4+H))-1 -: (4+H)]);
                                accum[(6 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(6 *4)-1 -: 4]) + $unsigned(accum[(6 *(4+H))-1 -: (4+H)]);
                                accum[(5 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(5 *4)-1 -: 4]) + $unsigned(accum[(5 *(4+H))-1 -: (4+H)]);
                                
                                accum[(4 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(4 *4)-1 -: 4]) + $unsigned(accum[(4 *(4+H))-1 -: (4+H)]);
                                accum[(3 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(3 *4)-1 -: 4]) + $unsigned(accum[(3 *(4+H))-1 -: (4+H)]);
                                accum[(2 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(2 *4)-1 -: 4]) + $unsigned(accum[(2 *(4+H))-1 -: (4+H)]);
                                accum[(1 *(4+H))-1 -: (4+H)] <= $unsigned(mult_exp[(1 *4)-1 -: 4]) + $unsigned(accum[(1 *(4+H))-1 -: (4+H)]);
                            end
                            4'b0010: begin
                                accum[(8 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(8 *5)-1 -: 5]) + $unsigned(accum[(8 *(5+H))-1 -: (5+H)]);
                                accum[(7 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(7 *5)-1 -: 5]) + $unsigned(accum[(7 *(5+H))-1 -: (5+H)]);
                                accum[(6 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(6 *5)-1 -: 5]) + $unsigned(accum[(6 *(5+H))-1 -: (5+H)]);
                                accum[(5 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(5 *5)-1 -: 5]) + $unsigned(accum[(5 *(5+H))-1 -: (5+H)]);
                                
                                accum[(4 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(4 *5)-1 -: 5]) + $unsigned(accum[(4 *(5+H))-1 -: (5+H)]);
                                accum[(3 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(3 *5)-1 -: 5]) + $unsigned(accum[(3 *(5+H))-1 -: (5+H)]);
                                accum[(2 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(2 *5)-1 -: 5]) + $unsigned(accum[(2 *(5+H))-1 -: (5+H)]);
                                accum[(1 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(1 *5)-1 -: 5]) + $unsigned(accum[(1 *(5+H))-1 -: (5+H)]);
                            end
                            4'b0011: begin
                                accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                            end
                            4'b1000: begin
                                accum[(8 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(8 *5)-1 -: 5]) + $unsigned(accum[(8 *(5+H))-1 -: (5+H)]);
                                accum[(7 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(7 *5)-1 -: 5]) + $unsigned(accum[(7 *(5+H))-1 -: (5+H)]);
                                accum[(6 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(6 *5)-1 -: 5]) + $unsigned(accum[(6 *(5+H))-1 -: (5+H)]);
                                accum[(5 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(5 *5)-1 -: 5]) + $unsigned(accum[(5 *(5+H))-1 -: (5+H)]);
                                
                                accum[(4 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(4 *5)-1 -: 5]) + $unsigned(accum[(4 *(5+H))-1 -: (5+H)]);
                                accum[(3 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(3 *5)-1 -: 5]) + $unsigned(accum[(3 *(5+H))-1 -: (5+H)]);
                                accum[(2 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(2 *5)-1 -: 5]) + $unsigned(accum[(2 *(5+H))-1 -: (5+H)]);
                                accum[(1 *(5+H))-1 -: (5+H)] <= $unsigned(mult_exp[(1 *5)-1 -: 5]) + $unsigned(accum[(1 *(5+H))-1 -: (5+H)]);
                            end
                            4'b1010: begin
                                accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                            end
                            4'b1011: begin
                                accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                            end
                            4'b1100: begin
                                accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                            end
                            4'b1110: begin
                                accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                            end
                            4'b1111: begin
                                accum <= $unsigned(accum) + $unsigned(mult_exp);
                            end
                        endcase
                    end
                    2'b11: begin
                        if (rst)           accum <= '0; 
                        else if (accum_en) accum <= accum + mult_exp; 
                    end
                endcase
            end
            
            1'b1: begin
                case(BG)
                    2'b00: begin
                        if (rst) accum <= '0;
                        else case(prec)
                            4'b0000: begin    // 8bx8b
                                accum <= $unsigned(accum) + $unsigned(mult_exp);
                            end
                            4'b1010: begin   // 4bx4b
                                case({MODE[3], MODE[2]})
                                    2'b00: begin
                                        accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                        accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                                    end
                                    2'b11: begin
                                        accum <= $unsigned(accum) + $unsigned(mult_exp);
                                    end
                                endcase
                            end
                            4'b1111: begin   // 2bx2b
                                case(MODE)
                                    4'b0000: begin
                                        accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                        accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                        accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                        accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                                    end
                                    4'b0011: begin
                                        accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                        accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                                    end
                                    4'b1100: begin
                                        accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                        accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                                    end
                                    4'b1111: begin
                                        accum <= $unsigned(accum) + $unsigned(mult_exp);
                                    end
                                endcase
                            end
                        endcase
                    end
                    2'b01: begin
                        if (rst) accum <= '0;
                        else case(MODE)
                            4'b0000: begin
                                accum[(4 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(4 *QM)-1 -: QM]) + $unsigned(accum[(4 *QZ)-1 -: QZ]);
                                accum[(3 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(3 *QM)-1 -: QM]) + $unsigned(accum[(3 *QZ)-1 -: QZ]);
                                accum[(2 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(2 *QM)-1 -: QM]) + $unsigned(accum[(2 *QZ)-1 -: QZ]);
                                accum[(1 *QZ)-1 -: QZ] <= $unsigned(mult_exp[(1 *QM)-1 -: QM]) + $unsigned(accum[(1 *QZ)-1 -: QZ]);
                            end
                            4'b0011: begin
                                accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                            end
                            4'b1100: begin
                                accum[(2 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(2 *MM)-1 -: MM]) + $unsigned(accum[(2 *MZ)-1 -: MZ]);
                                accum[(1 *MZ)-1 -: MZ] <= $unsigned(mult_exp[(1 *MM)-1 -: MM]) + $unsigned(accum[(1 *MZ)-1 -: MZ]);
                            end
                            4'b1111: begin
                                accum <= $unsigned(accum) + $unsigned(mult_exp);
                            end
                        endcase
                    end
                    2'b11: begin
                        //BOOKMARK: Edit Temporal DVAFS design
                    end
                endcase
            end
        endcase
    end
    
    //-------------Assertions----------------------------
    
    // Sequence for Variable Delay! 
    // Simply using |=> ##clk_to_out (condition) result in an error
    // Use |=> delay_seq(clk_to_out) |=> (condition) instead
    // For more info: https://verificationguide.com/systemverilog/systemverilog-variable-delay-in-sva/
    sequence delay_seq(v_delay);
        int delay;
        (1,delay=v_delay) ##0 first_match((1,delay=delay-1) [*0:$] ##0 delay <=0);
    endsequence
    
    property accumulation_temporal;
        logic [Z_WIDTH-1:0]     z_old = 0;
        logic [Z_WIDTH-1:0]     accum_old = 0;
        int                     z_exp = 0;
        logic [MULT_WIDTH-1:0]  m_exp = 0;
        // step 1: check established inputs at posedge
        @(negedge clk) (!rst)
        // input processing
        |=> @(posedge clk) (1'b1, 
            m_exp = mult_exp,
            z_exp = accum			
        )
        |=> delay_seq(clk_to_out) |=> (z_exp == z)
    endproperty // accumulation


    property accumulation_spatial;
        logic [Z_WIDTH-1:0]     z_old = 0;
        logic [Z_WIDTH-1:0]     accum_old = 0;
        logic [Z_WIDTH-1:0]     z_exp = 0;
        logic [MULT_WIDTH-1:0]  m_exp = 0;
        integer                 a_val, w_val;
        // step 1: check established inputs at posedge
        @(negedge clk) (!rst,
            z_old = z,
            accum_old = accum
        )
        // input processing
        // |=> @(posedge clk) (!rst, 
        // 	m_exp = $unsigned(a[0]) * $unsigned(w[0]),
        |=> @(posedge clk) (1'b1, 
            a_val = $unsigned(a[0]),
            w_val = $unsigned(w[0]),
            m_exp = mult_exp,
            $display("---------------------------------------------"), 
            $display("Old value:  %h (%7d) - %0t", z_old, $unsigned(z_old), $time),
            $display("New arith:  %h x %h = %h (%7d) - %0t", w_val, a_val, m_exp, $unsigned(m_exp), $time)
            
        )
        |=> @(negedge clk) (1'b1, 
            // print
            z_exp = accum,
            $display("Exp value:  %h + %h = %h (%d) - %0t", mult_exp, accum_old, accum, $unsigned(z_exp), $time),
            $display("Observed:   %h (%d) - %0t\n", z, $signed(z), $time)
        )
        |-> ##1 (z_exp == z)
    endproperty // accumulation

    generate
        if(BG[1]) always @(posedge clk) assert property (accumulation_temporal);
        else      always @(posedge clk) assert property (accumulation_spatial);
    endgenerate
    
endmodule