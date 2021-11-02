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
// File Name: tb_L4_mac.sv
// Design:    test_L4
// Function:  Testbench for L4_mult/L4_mac
//-----------------------------------------------------

module test_L4 ();

  //-------------Parameters------------------------------
  parameter       HEADROOM = 4; 
  parameter       L4_MODE  = 2'b11; 
  parameter       L3_MODE  = 2'b11;
  parameter       L2_MODE  = 4'b1111;   // Determines if in/out are shared for x/y dimensions
                                        // 0: input shared, 1: output shared
                                        // MODE[3:2] -> L2_mac, MODE[1:0] -> L1_mult
  parameter       BG     = 2'b11;       // Bitgroups (00: unroll in L2, 01: unroll in L3, 11: Unroll Temporally)
  parameter       DVAFS  = 1'b0;
  parameter       SIZE   = 4; 
  
  //-------------Local parameters------------------------
  localparam      RST           = 2; 
  localparam      REP           = 256;
  localparam      OUT_STATION   = 128; 
  localparam      L2_HELP_MODE  = BG[1] ? 4'b1111 : L2_MODE;                      // If Temporal: Override L2_MODE to be 4'b1111
  localparam      HEADROOM_HELP = BG[1] ? HEADROOM-4 : HEADROOM;                  // If Temporal: Headroom is partially incorporated in L2
  localparam      L2_A_INPUTS   = helper::get_L2_A_inputs(DVAFS, L2_HELP_MODE);
  localparam      L2_W_INPUTS   = helper::get_L2_W_inputs(DVAFS, L2_HELP_MODE);
  localparam      L2_OUT_WIDTH  = helper::get_L2_out_width(DVAFS, BG, L2_HELP_MODE);   // Width of the multiplication
                                                                                  // See function definitions at helper package
  localparam      L3_A_INPUTS   = helper::get_ARR_A_inputs(L3_MODE);
  localparam      L3_W_INPUTS   = helper::get_ARR_W_inputs(L3_MODE);
  localparam      L3_OUT_WIDTH  = helper::get_L3_out_width(DVAFS, BG, {L3_MODE, L2_HELP_MODE});
  localparam      L4_A_INPUTS   = helper::get_ARR_A_inputs(L4_MODE);
  localparam      L4_W_INPUTS   = helper::get_ARR_W_inputs(L4_MODE);
  localparam      L4_OUT_WIDTH  = helper::get_L4_out_width(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, SIZE);
  localparam      L4_MAX_OUTS   = helper::get_L4_max_outs(DVAFS, {L4_MODE, L3_MODE, L2_HELP_MODE}, SIZE);

  localparam      Z_WIDTH       = L4_OUT_WIDTH + (L4_MAX_OUTS * HEADROOM_HELP); 

  // L4_out divided into (DIV) points
  function int X_DIV(input int DIV); 
    // We first check if L4_OUT_WIDTH > (DIV), because if fraction is <1, it returns 0 (raises error)
    return (L4_OUT_WIDTH < DIV) ? 1 : L4_OUT_WIDTH / DIV; 
  endfunction
  
  // Flip 2 <-> 1
  function int flip(input int a); 
    if(a==0||a==3) return a; 
    else if(a==1)  return 2; 
    else if(a==2)  return 1; 
    else return 0; 
  endfunction

  localparam      OUTS_88       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b0000); 
  localparam      OUTS_84       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b0010);
  localparam      OUTS_82       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b0011); 
  localparam      OUTS_44       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b1010);
  localparam      OUTS_22       = helper::get_outs_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b1111); 
  localparam      WIDTH_88      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b0000); 
  localparam      WIDTH_84      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b0010); 
  localparam      WIDTH_82      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b0011); 
  localparam      WIDTH_44      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b1010); 
  localparam      WIDTH_22      = helper::get_width_prec(DVAFS, BG, {L4_MODE, L3_MODE, L2_HELP_MODE}, 4'b1111); 
  localparam      H             = HEADROOM_HELP; 

  // Logic for top_L4_mult module
  logic                   clk, rst, accum_en; 
  // Here, 3rd dimension [4] is the size of L3 mult, in our case its fixed to 4x4 L2 units
  logic    [7:0]          a       [SIZE][L4_A_INPUTS][4][L3_A_INPUTS][L2_A_INPUTS];   
  logic    [7:0]          w       [SIZE][L4_W_INPUTS][4][L3_W_INPUTS][L2_W_INPUTS];   
  `ifdef BIT_SERIAL 
  logic    [7:0]          a_full  [SIZE][L4_A_INPUTS][4][L3_A_INPUTS][4][4];   
  logic    [7:0]          w_full  [SIZE][L4_W_INPUTS][4][L3_W_INPUTS][4][4];   
  `else
  logic    [7:0]          a_full  [SIZE][L4_A_INPUTS][4][L3_A_INPUTS][L2_A_INPUTS];   
  logic    [7:0]          w_full  [SIZE][L4_W_INPUTS][4][L3_W_INPUTS][L2_W_INPUTS];   
  `endif
  logic    [3:0]          prec;       // 9 cases of precision (activation * weight)
                                      // prec[3:2]: Activation precision, prec[1:0]: Weight precision
                                      // 00: 8b, 10: 4b, 11: 2b
  logic    [Z_WIDTH-1:0]  z;   
  
  // Outputs of each functional unit 
  logic    [15:0]         out_88  [SIZE][SIZE][4][4];         // [L3_X][L3_Y][L2_X][L2_Y] 
  logic    [11:0]         out_84  [SIZE][SIZE][4][4][2];      // [L3_X][L3_Y][L2_X][L2_Y][L0_X]
  logic    [9:0]          out_82  [SIZE][SIZE][4][4][4];      // [L3_X][L3_Y][L2_X][L2_Y][L0_X]
  logic    [7:0]          out_44  [SIZE][SIZE][4][4][2][2];   // [L3_X][L3_Y][L2_X][L2_Y][L1_X]
  logic    [3:0]          out_22  [SIZE][SIZE][4][4][4][4];   // [L3_X][L3_Y][L2_X][L2_Y][L1_X]
  `ifdef BIT_SERIAL
  logic    [19:0]         out_bit_serial  [SIZE][SIZE][4][4];
  `endif

  // Expected Results
  logic    [L4_OUT_WIDTH-1:0]   mult_exp;
  logic    [Z_WIDTH-1:0]        accum_exp, accum;
  logic                         tst_ac_en, accum_en_reg;

  always_ff @(negedge clk) begin
    if(rst) accum_en_reg <= 0; 
    else    accum_en_reg <= accum_en; 
  end

  //-------------UUT Instantiation-----------------------
  top_L4_mac #(
    .HEADROOM (HEADROOM), 
    .L4_MODE  (L4_MODE), 
    .L3_MODE  (L3_MODE),
    .L2_MODE  (L2_HELP_MODE), 
    .BG       (BG), 
    .DVAFS    (DVAFS), 
    .SIZE     (SIZE)
  ) top_L4_mac (
    .clk      (clk),
    .rst      (rst),
    .prec     (prec), 
    `ifdef BIT_SERIAL
    .accum_en (accum_en_reg), 
    `else 
    .accum_en (accum_en), 
    `endif
    .a        (a), 
    .w        (w), 
    .z        (z)
  );
  
  int     prec_w, prec_a, clk_to_out; 
  `ifdef BIT_SERIAL
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
  `endif

  //-------------Clock-----------------------------------
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Relation between top_L4_mac inputs and Full input! 
  `ifndef BIT_SERIAL
  always_comb begin
    case(BG)
      2'b00: begin
        a = a_full; 
        w = w_full; 
      end
      2'b01: begin
        for(int l=0; l<SIZE; l++) begin
          for(int k=0; k<L4_A_INPUTS; k++) begin
            for(int i=0; i<L3_A_INPUTS; i++) begin
              for(int j=0; j<L2_A_INPUTS; j++) begin
                a[l][k][0][i][j] = {a_full[l][k][3][i][j][1:0], a_full[l][k][2][i][j][1:0], a_full[l][k][1][i][j][1:0], a_full[l][k][0][i][j][1:0]};
                a[l][k][1][i][j] = {a_full[l][k][3][i][j][3:2], a_full[l][k][2][i][j][3:2], a_full[l][k][1][i][j][3:2], a_full[l][k][0][i][j][3:2]};
                a[l][k][2][i][j] = {a_full[l][k][3][i][j][5:4], a_full[l][k][2][i][j][5:4], a_full[l][k][1][i][j][5:4], a_full[l][k][0][i][j][5:4]};
                a[l][k][3][i][j] = {a_full[l][k][3][i][j][7:6], a_full[l][k][2][i][j][7:6], a_full[l][k][1][i][j][7:6], a_full[l][k][0][i][j][7:6]};
              end
            end
          end
        end
        for(int l=0; l<SIZE; l++) begin
          for(int k=0; k<L4_W_INPUTS; k++) begin
            for(int i=0; i<L3_W_INPUTS; i++) begin
              for(int j=0; j<L2_W_INPUTS; j++) begin
                w[l][k][0][i][j] = {w_full[l][k][3][i][j][1:0], w_full[l][k][2][i][j][1:0], w_full[l][k][1][i][j][1:0], w_full[l][k][0][i][j][1:0]};
                w[l][k][1][i][j] = {w_full[l][k][3][i][j][3:2], w_full[l][k][2][i][j][3:2], w_full[l][k][1][i][j][3:2], w_full[l][k][0][i][j][3:2]};
                w[l][k][2][i][j] = {w_full[l][k][3][i][j][5:4], w_full[l][k][2][i][j][5:4], w_full[l][k][1][i][j][5:4], w_full[l][k][0][i][j][5:4]};
                w[l][k][3][i][j] = {w_full[l][k][3][i][j][7:6], w_full[l][k][2][i][j][7:6], w_full[l][k][1][i][j][7:6], w_full[l][k][0][i][j][7:6]};
              end
            end
          end
        end
      end
    endcase
  end
  `endif

  // Bench for spatial unrolling
  task bench_spatial(input bit [3:0] precision);
    // initial reset
    rst   =  1;
    $assertoff;
    $assertkill;
    a_full = '{default:0};
    w_full = '{default:0};
    repeat (5) @(negedge clk);
    prec = precision;
    repeat (RST) @(negedge clk) begin
      // reset
      rst    =  1;
      $assertoff;
      $assertkill;
      repeat (1) @(negedge clk);
      rst    =  0;
      $asserton;
      tst_ac_en = 1;
      fork
        begin  
          repeat(REP/OUT_STATION) begin
            accum_en = 0; 
            @(negedge clk);
            accum_en = 1; 
            repeat (OUT_STATION-1) @(negedge clk);
          end
        end
        begin
          repeat (REP) begin
            void'(randomize(a_full));
            void'(randomize(w_full));
            @(negedge clk);
          end
        end
      join
    end
  endtask

  `ifdef BIT_SERIAL
  // Bench for temporal unrolling
  task bench_temporal(input bit [3:0] precision);
    // initial reset
    rst    =  1;
    $assertoff;
    $assertkill;
    a_full = '{default:0};
    w_full = '{default:0};
    repeat (5) @(negedge clk);
    prec = precision;
    repeat (RST) @(negedge clk) begin
      // reset
      rst      =  1;
      $assertoff;
      $assertkill;
      repeat (1) @(negedge clk);
      rst      =  0;
      $asserton;
      fork
        begin  
          repeat(REP/(OUT_STATION)) begin
            accum_en = 0; 
            repeat (clk_to_out) @(negedge clk);
            accum_en = 1; 
            repeat (OUT_STATION-clk_to_out) @(negedge clk);
          end
        end
        begin
          repeat (REP/clk_to_out) begin
            tst_ac_en = 1; 
            foreach(a_full[i,j,k,l,m,n]) a_full[i][j][k][l][m][n] = $urandom()%255 >> (8-prec_a);
            foreach(w_full[i,j,k,l,m,n]) w_full[i][j][k][l][m][n] = $urandom()%255 >> (8-prec_w);
            for(int i=0; i<prec_w; i=i+2) begin
              for(int j=0; j<prec_a; j=j+2) begin
                for(int k=0; k<SIZE; k++) begin
                  for(int l=0; l<L4_A_INPUTS; l++) begin
                    for(int m=0; m<4; m++) begin
                      for(int n=0; n<L3_A_INPUTS; n++) begin
                        a[k][l][m][n][0] = {a_full[k][l][m][n][3][0][j+:2], a_full[k][l][m][n][2][0][j+:2], a_full[k][l][m][n][1][0][j+:2], a_full[k][l][m][n][0][0][j+:2]};
                        a[k][l][m][n][1] = {a_full[k][l][m][n][3][2][j+:2], a_full[k][l][m][n][2][2][j+:2], a_full[k][l][m][n][1][2][j+:2], a_full[k][l][m][n][0][2][j+:2]};
                        a[k][l][m][n][2] = {a_full[k][l][m][n][3][1][j+:2], a_full[k][l][m][n][2][1][j+:2], a_full[k][l][m][n][1][1][j+:2], a_full[k][l][m][n][0][1][j+:2]};
                        a[k][l][m][n][3] = {a_full[k][l][m][n][3][3][j+:2], a_full[k][l][m][n][2][3][j+:2], a_full[k][l][m][n][1][3][j+:2], a_full[k][l][m][n][0][3][j+:2]};
                        
                        w[k][l][m][n][0] = {w_full[k][l][m][n][0][0][i+:2], w_full[k][l][m][n][0][1][i+:2], w_full[k][l][m][n][0][2][i+:2], w_full[k][l][m][n][0][3][i+:2]};
                        w[k][l][m][n][1] = {w_full[k][l][m][n][2][0][i+:2], w_full[k][l][m][n][2][1][i+:2], w_full[k][l][m][n][2][2][i+:2], w_full[k][l][m][n][2][3][i+:2]};
                        w[k][l][m][n][2] = {w_full[k][l][m][n][1][0][i+:2], w_full[k][l][m][n][1][1][i+:2], w_full[k][l][m][n][1][2][i+:2], w_full[k][l][m][n][1][3][i+:2]};
                        w[k][l][m][n][3] = {w_full[k][l][m][n][3][0][i+:2], w_full[k][l][m][n][3][1][i+:2], w_full[k][l][m][n][3][2][i+:2], w_full[k][l][m][n][3][3][i+:2]};
                      end
                    end
                  end
                end
                @(negedge clk); 
                tst_ac_en = 0; 
              end
            end
          end
        end
      join
    end
  endtask
  `endif
  
  // Actual Bench execution
  initial begin
    casex(BG)
      2'b0x: begin // BG_Spatial
        bench_spatial(4'b0000);    // 8bx8b
        if(!DVAFS) begin 
          bench_spatial(4'b0010);  // 8bx4b
          bench_spatial(4'b0011);  // 8bx2b
        end
        bench_spatial(4'b1010);    // 4bx4b
        bench_spatial(4'b1111);    // 2bx2b
      end

      2'b11: begin
        `ifdef BIT_SERIAL
          bench_temporal(4'b0000); 
          bench_temporal(4'b0010); 
          bench_temporal(4'b0011); 
          bench_temporal(4'b1010); 
          bench_temporal(4'b1111); 
        `endif
      end
    endcase
    $stop;
  end
  
  // Outputs of each functional unit 
  `ifdef BIT_SERIAL
  always_comb begin
    out_bit_serial = '{default:0};
    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
          for(int L2_X=0; L2_X<4; L2_X++) begin
            for(int i=0; i<4; i++) begin
              for(int j=0; j<4; j++) begin
                out_bit_serial[L3_Y][L3_X][L2_Y][L2_X] += a_full[L3_Y  ][L4_MODE[1]? L3_X:0][L2_Y  ][L3_MODE[1]? flip(L2_X):0][i][j] 
                                                        * w_full[3-L3_X][L4_MODE[0]? L3_Y:0][3-L2_X][L3_MODE[0]? flip(L2_Y):0][i][j]; 
              end
            end
          end
        end
      end
    end
  end
  `else
  always_comb begin
    case(prec)
      4'b0000: begin //8x8 - Don't care about L2_MODE if BG_L2 - Don't care about L3_MODE if BG_L3
        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
              for(int L2_X=0; L2_X<4; L2_X++) begin
                out_88[L3_Y][L3_X][L2_Y][L2_X] = a_full[L3_Y  ][L4_MODE[1]? L3_X:0][L2_Y  ][BG[0] ? 0:(L3_MODE[1]? flip(L2_X):0)][BG[0] ? (L2_MODE[1]? flip(L2_X):0):0] 
                                               * w_full[3-L3_X][L4_MODE[0]? L3_Y:0][3-L2_X][BG[0] ? 0:(L3_MODE[0]? flip(L2_Y):0)][BG[0] ? (L2_MODE[0]? flip(L2_Y):0):0]; 
              end
            end
          end
        end
      end
      4'b0010: begin //8x4
        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
              for(int L2_X=0; L2_X<4; L2_X++) begin
                for(int L0_X=0; L0_X<2; L0_X++) begin
                  out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X] = a_full[L3_Y  ][L4_MODE[1]? L3_X:0][L2_Y  ][BG[0] ? (L3_MODE[1]? L0_X:0):(L3_MODE[1]? flip(L2_X):0)][BG[0] ? (L2_MODE[1]? flip(L2_X):0):(L2_MODE[1]? L0_X:0)]        // Don't flip L2 here - either 0 or 1 
                                                       * w_full[3-L3_X][L4_MODE[0]? L3_Y:0][3-L2_X][BG[0] ? 0:                   (L3_MODE[0]? flip(L2_Y):0)][BG[0] ? (L2_MODE[0]? flip(L2_Y):0):  0                 ][7-(4*L0_X)-:4]; 
                end
              end
            end
          end
        end
      end
      4'b0011: begin //8x2
        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
              for(int L2_X=0; L2_X<4; L2_X++) begin
                for(int L0_X=0; L0_X<4; L0_X++) begin
                  out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X] = a_full[L3_Y  ][L4_MODE[1]? L3_X:0][L2_Y  ][BG[0] ? (L3_MODE[1]? flip(L0_X):0):(L3_MODE[1]? flip(L2_X):0)][BG[0] ? (L2_MODE[1]? flip(L2_X):0):(L2_MODE[1]? flip(L0_X):0)]        
                                                       * w_full[3-L3_X][L4_MODE[0]? L3_Y:0][3-L2_X][BG[0] ? 0:                         (L3_MODE[0]? flip(L2_Y):0)][BG[0] ? (L2_MODE[0]? flip(L2_Y):0):0                         ][7-(2*L0_X)-:2]; 
                end
              end
            end
          end
        end
      end
      4'b1010: begin //4x4 
        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
              for(int L2_X=0; L2_X<4; L2_X++) begin
                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                  for(int L0_X=0; L0_X<2; L0_X++) begin
                    out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X] = a_full[L3_Y  ][L4_MODE[1]? L3_X:0][L2_Y  ][BG[0] ? (L3_MODE[1]? L0_X:0):(L3_MODE[1]? flip(L2_X):0)][BG[0] ? (L2_MODE[1]? flip(L2_X):0):(DVAFS ? 0:(L2_MODE[1]? L0_X:0))][0+(4*L0_Y)+:4]     // Don't flip here - either 0 or 1 
                                                               * w_full[3-L3_X][L4_MODE[0]? L3_Y:0][3-L2_X][BG[0] ? (L3_MODE[0]? L0_Y:0):(L3_MODE[0]? flip(L2_Y):0)][BG[0] ? (L2_MODE[0]? flip(L2_Y):0):(DVAFS ? 0:(L2_MODE[0]? L0_Y:0))][7-(4*L0_X)-:4]; 
                  end
                end
              end
            end
          end
        end
      end
      4'b1111: begin
        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
              for(int L2_X=0; L2_X<4; L2_X++) begin
                for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                  for(int L0_X=0; L0_X<4; L0_X++) begin
                    out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X] = a_full[L3_Y  ][L4_MODE[1]? L3_X:0][L2_Y  ][BG[0] ? (L3_MODE[1]? flip(L0_X):0):(L3_MODE[1]? flip(L2_X):0)][BG[0] ? (L2_MODE[1]? flip(L2_X):0):(DVAFS ? 0:(L2_MODE[1]? flip(L0_X):0))][0+(2*L0_Y)+:2]        
                                                               * w_full[3-L3_X][L4_MODE[0]? L3_Y:0][3-L2_X][BG[0] ? (L3_MODE[0]? flip(L0_Y):0):(L3_MODE[0]? flip(L2_Y):0)][BG[0] ? (L2_MODE[0]? flip(L2_Y):0):(DVAFS ? 0:(L2_MODE[0]? flip(L0_Y):0))][7-(2*L0_X)-:2]; 
                  end
                end
              end
            end
          end
        end
      end
    endcase
  end
  `endif

  // Expected Multiplication
  always_comb begin
    case(BG)
      2'b00: begin: BG_L2
        case(L4_MODE)
          2'b00: begin: L4_IN_IN
            case(L3_MODE)
              2'b00: begin
                case(prec)
                  4'b0000: begin
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] = out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L2_MODE[3])
                      1'b0: begin
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(512)*L0_X)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(512)] = out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case({L2_MODE[3], L2_MODE[1]})
                      2'b00: begin
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(1024)*L0_X)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(1024)] = out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case({L2_MODE[3], L2_MODE[2]})
                      2'b00: begin
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                      for(int L0_X=0; L0_X<2; L0_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(1024)*L0_X)-(X_DIV(512)*L0_Y)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(1024)] = out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(512)*L0_Y)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(512)] = out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(512)*L0_Y)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(512)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                      for(int L0_X=0; L0_X<2; L0_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];  
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                  4'b1111: begin
                    int L0_X, L0_Y; 
                    case(L2_MODE)
                      4'b0000: begin
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y1=0; L0_Y1<2; L0_Y1++) begin
                                      for(int L0_X1=0; L0_X1<2; L0_X1++) begin
                                        for(int L0_Y2=0; L0_Y2<2; L0_Y2++) begin
                                          for(int L0_X2=0; L0_X2<2; L0_X2++) begin
                                            L0_Y = (2*L0_Y1) + L0_Y2;
                                            L0_X = (2*L0_X1) + L0_X2;
                                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4096)*(L0_X2+2*L0_Y2))-(X_DIV(1024)*(L0_X1+2*L0_Y1))-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(4096)] = out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(1024)*L0_Y)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(1024)] = out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      4'b1010: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                  for(int L0_X=0; L0_X<4; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(1024)*L0_Y)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(1024)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      4'b1111: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                      for(int L0_X=0; L0_X<4; L0_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                endcase
              end
              2'b10: begin 
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L2_MODE[3])
                      1'b0: begin
                        mult_exp = '0;  
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_X=0; L0_X<2; L0_X++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(128)*L2_Y)-(X_DIV(32)*L0_X)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(128)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case({L2_MODE[3], L2_MODE[1]})
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_X=0; L0_X<4; L0_X++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_Y)-(X_DIV(64)*L0_X)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case({L2_MODE[3], L2_MODE[2]})
                      2'b00: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                      for(int L2_X=0; L2_X<4; L2_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_Y)-(X_DIV(64)*L0_X)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                    for(int L2_X=0; L2_X<4; L2_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(128)*L2_Y)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(128)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(128)*L2_Y)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(128)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                      for(int L0_X=0; L0_X<2; L0_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];  
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                  4'b1111: begin
                    int L0_X, L0_Y; 
                    case(L2_MODE)
                      4'b0000: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L0_Y1=0; L0_Y1<2; L0_Y1++) begin
                                  for(int L0_X1=0; L0_X1<2; L0_X1++) begin
                                    for(int L0_Y2=0; L0_Y2<2; L0_Y2++) begin
                                      for(int L0_X2=0; L0_X2<2; L0_X2++) begin
                                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                          for(int L2_X=0; L2_X<4; L2_X++) begin
                                            L0_Y = (2*L0_Y1) + L0_Y2;
                                            L0_X = (2*L0_X1) + L0_X2;
                                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(1024)*L2_Y)-(X_DIV(256)*(L0_X2+2*L0_Y2))-(X_DIV(64)*(L0_X1+2*L0_Y1))-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(1024)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                  for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                    for(int L2_X=0; L2_X<4; L2_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_Y)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      4'b1010: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_X=0; L0_X<4; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_Y)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      4'b1111: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                      for(int L0_X=0; L0_X<4; L0_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                endcase
              end
              2'b11: begin
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L2_MODE[3])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_X=0; L0_X<2; L0_X++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L0_X)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(32)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case({L2_MODE[3], L2_MODE[1]})
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_X=0; L0_X<4; L0_X++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_X)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X];
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case({L2_MODE[3], L2_MODE[2]})
                      2'b00: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                      for(int L2_X=0; L2_X<4; L2_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_X)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                    for(int L2_X=0; L2_X<4; L2_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(32)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(32)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                      for(int L0_X=0; L0_X<2; L0_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];  
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                  4'b1111: begin
                    int L0_X, L0_Y; 
                    case(L2_MODE)
                      4'b0000: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L0_Y1=0; L0_Y1<2; L0_Y1++) begin
                                  for(int L0_X1=0; L0_X1<2; L0_X1++) begin
                                    for(int L0_Y2=0; L0_Y2<2; L0_Y2++) begin
                                      for(int L0_X2=0; L0_X2<2; L0_X2++) begin
                                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                          for(int L2_X=0; L2_X<4; L2_X++) begin
                                            L0_Y = (2*L0_Y1) + L0_Y2;
                                            L0_X = (2*L0_X1) + L0_X2;
                                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*(L0_X2+2*L0_Y2))-(X_DIV(64)*(L0_X1+2*L0_Y1))-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin 
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                  for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                    for(int L2_X=0; L2_X<4; L2_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      4'b1010: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_X=0; L0_X<4; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      4'b1111: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                      for(int L0_X=0; L0_X<4; L0_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                endcase
              end
            endcase
          end
          2'b10: begin: L4_OUT_IN
            case(L3_MODE)
              2'b00: begin: L3_IN_IN
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                      for(int L2_X=0; L2_X<4; L2_X++) begin
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L2_MODE[3])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L0_X=0; L0_X<2; L0_X++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(128)*L3_Y)-(X_DIV(32)*L0_X)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(128)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case({L2_MODE[3], L2_MODE[1]})
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L0_X=0; L0_X<4; L0_X++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L3_Y)-(X_DIV(64)*L0_X)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(256)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case({L2_MODE[3], L2_MODE[2]})
                      2'b00: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L3_Y)-(X_DIV(64)*L0_X)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(256)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(128)*L3_Y)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(128)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(128)*L3_Y)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(128)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L0_X=0; L0_X<2; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];  
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                  4'b1111: begin
                    int L0_X, L0_Y; 
                    case(L2_MODE)
                      4'b0000: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y1=0; L0_Y1<2; L0_Y1++) begin
                                  for(int L0_X1=0; L0_X1<2; L0_X1++) begin
                                    for(int L0_Y2=0; L0_Y2<2; L0_Y2++) begin
                                      for(int L0_X2=0; L0_X2<2; L0_X2++) begin
                                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                            L0_Y = (2*L0_Y1) + L0_Y2;
                                            L0_X = (2*L0_X1) + L0_X2;
                                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(1024)*L3_Y)-(X_DIV(256)*(L0_X2+2*L0_Y2))-(X_DIV(64)*(L0_X1+2*L0_Y1))-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(1024)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                  for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L3_Y)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      4'b1010: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L3_Y)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      4'b1111: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L0_X=0; L0_X<4; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                endcase
              end
              2'b10: begin: L3_OUT_IN
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                      for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                        for(int L2_X=0; L2_X<4; L2_X++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L2_MODE[3])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<2; L0_X++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L3_Y)-(X_DIV(8)*L2_Y)-(X_DIV(2)*L0_X)-:X_DIV(32)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case({L2_MODE[3], L2_MODE[1]})
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<4; L0_X++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_Y)-(X_DIV(4)*L0_X)-:X_DIV(64)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case({L2_MODE[3], L2_MODE[2]})
                      2'b00: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                    for(int L2_X=0; L2_X<4; L2_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_Y)-(X_DIV(4)*L0_X)-(X_DIV(2)*L0_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L3_Y)-(X_DIV(8)*L2_Y)-(X_DIV(2)*L0_Y)-:X_DIV(32)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L3_Y)-(X_DIV(8)*L2_Y)-(X_DIV(2)*L0_Y)-:X_DIV(32)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L0_X=0; L0_X<2; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];  
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                  4'b1111: begin
                    int L0_X, L0_Y; 
                    case(L2_MODE)
                      4'b0000: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L0_Y1=0; L0_Y1<2; L0_Y1++) begin
                              for(int L0_X1=0; L0_X1<2; L0_X1++) begin
                                for(int L0_Y2=0; L0_Y2<2; L0_Y2++) begin
                                  for(int L0_X2=0; L0_X2<2; L0_X2++) begin
                                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                      for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                        for(int L2_X=0; L2_X<4; L2_X++) begin
                                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                            L0_Y = (2*L0_Y1) + L0_Y2;
                                            L0_X = (2*L0_X1) + L0_X2;
                                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L3_Y)-(X_DIV(64)*L2_Y)-(X_DIV(16)*(L0_X2+2*L0_Y2))-(X_DIV(4)*(L0_X1+2*L0_Y1))-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_Y)-(X_DIV(4)*L0_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      4'b1010: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_Y)-(X_DIV(4)*L0_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      4'b1111: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L0_X=0; L0_X<4; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                endcase
              end
              2'b11: begin: L3_OUT_OUT
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                        for(int L2_X=0; L2_X<4; L2_X++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L2_MODE[3])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<2; L0_X++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L3_Y)-(X_DIV(2)*L0_X)-:X_DIV(8)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case({L2_MODE[3], L2_MODE[1]})
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<4; L0_X++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L0_X)-:X_DIV(16)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case({L2_MODE[3], L2_MODE[2]})
                      2'b00: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                    for(int L2_X=0; L2_X<4; L2_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L0_X)-(X_DIV(2)*L0_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L3_Y)-(X_DIV(2)*L0_Y)-:X_DIV(8)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L3_Y)-(X_DIV(2)*L0_Y)-:X_DIV(8)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L0_X=0; L0_X<2; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];  
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                  4'b1111: begin
                    int L0_X, L0_Y; 
                    case(L2_MODE)
                      4'b0000: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L0_Y1=0; L0_Y1<2; L0_Y1++) begin
                              for(int L0_X1=0; L0_X1<2; L0_X1++) begin
                                for(int L0_Y2=0; L0_Y2<2; L0_Y2++) begin
                                  for(int L0_X2=0; L0_X2<2; L0_X2++) begin
                                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                      for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                        for(int L2_X=0; L2_X<4; L2_X++) begin
                                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                            L0_Y = (2*L0_Y1) + L0_Y2;
                                            L0_X = (2*L0_X1) + L0_X2;
                                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*(L0_X2+2*L0_Y2))-(X_DIV(4)*(L0_X1+2*L0_Y1))-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L0_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      4'b1010: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L0_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      4'b1111: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L0_X=0; L0_X<4; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                endcase
              end
            endcase
          end
          2'b11: begin: L4_OUT_OUT
            case(L3_MODE)
              2'b00: begin: L3_IN_IN
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                      for(int L2_X=0; L2_X<4; L2_X++) begin
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L2_MODE[3])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L0_X=0; L0_X<2; L0_X++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L0_X)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(32)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case({L2_MODE[3], L2_MODE[1]})
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L0_X=0; L0_X<4; L0_X++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_X)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case({L2_MODE[3], L2_MODE[2]})
                      2'b00: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_X)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(32)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(32)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L0_X=0; L0_X<2; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];  
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                  4'b1111: begin
                    int L0_X, L0_Y; 
                    case(L2_MODE)
                      4'b0000: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y1=0; L0_Y1<2; L0_Y1++) begin
                                  for(int L0_X1=0; L0_X1<2; L0_X1++) begin
                                    for(int L0_Y2=0; L0_Y2<2; L0_Y2++) begin
                                      for(int L0_X2=0; L0_X2<2; L0_X2++) begin
                                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                            L0_Y = (2*L0_Y1) + L0_Y2;
                                            L0_X = (2*L0_X1) + L0_X2;
                                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*(L0_X2+2*L0_Y2))-(X_DIV(64)*(L0_X1+2*L0_Y1))-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                  for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      4'b1010: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      4'b1111: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L0_X=0; L0_X<4; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                endcase
              end
              2'b10: begin: L3_OUT_IN
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                      for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                        for(int L2_X=0; L2_X<4; L2_X++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L2_MODE[3])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<2; L0_X++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L2_Y)-(X_DIV(2)*L0_X)-:X_DIV(8)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case({L2_MODE[3], L2_MODE[1]})
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<4; L0_X++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_Y)-(X_DIV(4)*L0_X)-:X_DIV(16)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case({L2_MODE[3], L2_MODE[2]})
                      2'b00: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                    for(int L2_X=0; L2_X<4; L2_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_Y)-(X_DIV(4)*L0_X)-(X_DIV(2)*L0_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L2_Y)-(X_DIV(2)*L0_Y)-:X_DIV(8)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L2_Y)-(X_DIV(2)*L0_Y)-:X_DIV(8)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L0_X=0; L0_X<2; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];  
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                  4'b1111: begin
                    int L0_X, L0_Y; 
                    case(L2_MODE)
                      4'b0000: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L0_Y1=0; L0_Y1<2; L0_Y1++) begin
                              for(int L0_X1=0; L0_X1<2; L0_X1++) begin
                                for(int L0_Y2=0; L0_Y2<2; L0_Y2++) begin
                                  for(int L0_X2=0; L0_X2<2; L0_X2++) begin
                                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                      for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                        for(int L2_X=0; L2_X<4; L2_X++) begin
                                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                            L0_Y = (2*L0_Y1) + L0_Y2;
                                            L0_X = (2*L0_X1) + L0_X2;
                                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*(L0_X2+2*L0_Y2))-(X_DIV(4)*(L0_X1+2*L0_Y1))-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_Y)-(X_DIV(4)*L0_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      4'b1010: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_Y)-(X_DIV(4)*L0_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      4'b1111: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L0_X=0; L0_X<4; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                endcase
              end
              2'b11: begin: L3_OUT_OUT
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                        for(int L2_X=0; L2_X<4; L2_X++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L2_MODE[3])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<2; L0_X++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(2)*L0_X)-:X_DIV(2)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case({L2_MODE[3], L2_MODE[1]})
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<4; L0_X++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L0_X)-:X_DIV(4)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case({L2_MODE[3], L2_MODE[2]})
                      2'b00: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                  for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                    for(int L2_X=0; L2_X<4; L2_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L0_X)-(X_DIV(2)*L0_Y)-:X_DIV(4)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(2)*L0_Y)-:X_DIV(2)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(2)*L0_Y)-:X_DIV(2)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L0_X=0; L0_X<2; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y];  
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                  4'b1111: begin
                    int L0_X, L0_Y; 
                    case(L2_MODE)
                      4'b0000: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L0_Y1=0; L0_Y1<2; L0_Y1++) begin
                              for(int L0_X1=0; L0_X1<2; L0_X1++) begin
                                for(int L0_Y2=0; L0_Y2<2; L0_Y2++) begin
                                  for(int L0_X2=0; L0_X2<2; L0_X2++) begin
                                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                      for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                        for(int L2_X=0; L2_X<4; L2_X++) begin
                                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                            L0_Y = (2*L0_Y1) + L0_Y2;
                                            L0_X = (2*L0_X1) + L0_X2;
                                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*(L0_X2+2*L0_Y2))-(X_DIV(4)*(L0_X1+2*L0_Y1))-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L0_Y)-:X_DIV(4)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                      4'b1010: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L0_Y)-:X_DIV(4)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      4'b1111: begin
                        mult_exp = '0; 
                        case(DVAFS)
                          1'b0: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L0_X=0; L0_X<4; L0_X++) begin
                                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                        mult_exp += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                          1'b1: begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                    for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                      mult_exp += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_Y]; 
                                    end
                                  end
                                end
                              end
                            end
                          end
                        endcase
                      end
                    endcase
                  end
                endcase
              end
            endcase
          end
        endcase
      end
      2'b01: begin: BG_L3 
        case(L4_MODE)
          2'b00: begin
            case(L2_MODE)
              4'b1010: begin  // L2_1010
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0;  
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(128)*L0_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(128)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L0_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L0_X)-(X_DIV(128)*L0_Y)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(128)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(128)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1111: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(1024)*L2_Y)-(X_DIV(256)*(L0_X))-(X_DIV(64)*(L0_Y))-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(1024)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_X=0; L0_X<4; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L0_Y)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                  for(int L0_X=0; L0_X<4; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                endcase
              end
              4'b1111: begin  // L2_1111
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L2_X=0; L2_X<4; L2_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_X=0; L0_X<2; L0_X++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L0_X)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(32)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_X=0; L0_X<4; L0_X++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_X)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X];
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_X=0; L0_X<2; L0_X++) begin
                              for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_Y)-(X_DIV(32)*L0_X)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(32)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                  for(int L0_X=0; L0_X<2; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1111: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                  for(int L2_X=0; L2_X<4; L2_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L0_X)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L0_X=0; L0_X<4; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L0_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                  for(int L0_X=0; L0_X<4; L0_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                endcase
              end
            endcase
          end
          2'b10: begin
            case(L2_MODE)
              4'b1010: begin
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                      for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                        for(int L2_X=0; L2_X<4; L2_X++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_X=0; L0_X<2; L0_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L3_Y)-(X_DIV(8)*L0_X)-(X_DIV(4)*L2_Y)-:X_DIV(32)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_X=0; L0_X<4; L0_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L0_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                            for(int L0_X=0; L0_X<2; L0_X++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L0_X)-(X_DIV(8)*L0_Y)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(32)*L3_Y)-(X_DIV(8)*L0_Y)-(X_DIV(4)*L2_Y)-:X_DIV(32)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1111: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L0_X=0; L0_X<4; L0_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L3_Y)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L0_X)-(X_DIV(4)*L0_Y)-:X_DIV(256)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L0_Y)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                endcase
              end
              4'b1111: begin
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                        for(int L2_X=0; L2_X<4; L2_X++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<2; L0_X++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L3_Y)-(X_DIV(2)*L0_X)-:X_DIV(8)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<4; L0_X++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L0_X)-:X_DIV(16)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<2; L0_X++) begin
                          for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L0_Y)-(X_DIV(2)*L0_X)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L3_Y)-(X_DIV(2)*L0_Y)-:X_DIV(8)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1111: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L0_X=0; L0_X<4; L0_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L0_X)-(X_DIV(4)*L0_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L0_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                endcase
              end
            endcase
          end
          2'b11: begin
            case(L2_MODE)
              4'b1010: begin
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                      for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                        for(int L2_X=0; L2_X<4; L2_X++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_X=0; L0_X<2; L0_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L0_X)-(X_DIV(4)*L2_Y)-:X_DIV(8)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_X=0; L0_X<4; L0_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L0_X)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                            for(int L0_X=0; L0_X<2; L0_X++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L0_X)-(X_DIV(8)*L0_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(8)*L0_Y)-(X_DIV(4)*L2_Y)-:X_DIV(8)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1111: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L0_X=0; L0_X<4; L0_X++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L0_X)-(X_DIV(4)*L0_Y)-:X_DIV(64)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-(X_DIV(16)*L0_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                endcase
              end
              4'b1111: begin
                case(prec)
                  4'b0000: begin
                    mult_exp = '0; 
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                        for(int L2_X=0; L2_X<4; L2_X++) begin
                          for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                            mult_exp += out_88[L3_Y][L3_X][L2_Y][L2_X]; 
                          end
                        end
                      end
                    end
                  end
                  4'b0010: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<2; L0_X++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(2)*L0_X)-:X_DIV(2)] += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<2; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp += out_84[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b0011: begin
                    case(L3_MODE[1])
                      1'b0: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<4; L0_X++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L0_X)-:X_DIV(4)] += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                      1'b1: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_X=0; L0_X<4; L0_X++) begin
                                for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                  mult_exp += out_82[L3_Y][L3_X][L2_Y][L2_X][L0_X]; 
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1010: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_X=0; L0_X<2; L0_X++) begin
                          for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L0_Y)-(X_DIV(2)*L0_X)-:X_DIV(4)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(2)*L0_Y)-:X_DIV(2)] += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_Y=0; L0_Y<2; L0_Y++) begin
                                for(int L0_X=0; L0_X<2; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp += out_44[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X];  
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                  4'b1111: begin
                    case(L3_MODE)
                      2'b00: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L0_X=0; L0_X<4; L0_X++) begin
                            for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                              for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                                for(int L2_X=0; L2_X<4; L2_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L0_X)-(X_DIV(4)*L0_Y)-:X_DIV(16)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b10: begin
                        mult_exp = '0; 
                        for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                          for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                            for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                              for(int L2_X=0; L2_X<4; L2_X++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L0_Y)-:X_DIV(4)] += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                      2'b11: begin
                        mult_exp = '0; 
                        for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                          for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                            for(int L2_X=0; L2_X<4; L2_X++) begin
                              for(int L0_Y=0; L0_Y<4; L0_Y++) begin
                                for(int L0_X=0; L0_X<4; L0_X++) begin
                                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                                    mult_exp += out_22[L3_Y][L3_X][L2_Y][L2_X][L0_Y][L0_X]; 
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    endcase
                  end
                endcase
              end
            endcase
          end
        endcase
      end
      2'b11: begin: BIT_SERIAL
        `ifdef BIT_SERIAL
        case(L4_MODE)
          2'b00: begin: L4_IN_IN
            case(L3_MODE)
              2'b00: begin: L3_IN_IN
                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                      for(int L2_X=0; L2_X<4; L2_X++) begin
                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(256)*L2_X)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(256)] = out_bit_serial[L3_Y][L3_X][L2_Y][L2_X]; 
                      end
                    end
                  end
                end
              end
              2'b10: begin: L3_OUT_IN
                mult_exp = '0; 
                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                      for(int L2_X=0; L2_X<4; L2_X++) begin
                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L2_Y)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(64)] += out_bit_serial[L3_Y][L3_X][L2_Y][L2_X]; 
                      end
                    end
                  end
                end
              end
              2'b11: begin: L3_OUT_OUT
                mult_exp = '0; 
                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                  for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                    for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                      for(int L2_X=0; L2_X<4; L2_X++) begin
                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_X)-(X_DIV(4)*L3_Y)-:X_DIV(16)] += out_bit_serial[L3_Y][L3_X][L2_Y][L2_X]; 
                      end
                    end
                  end
                end
              end
            endcase
          end
          2'b10: begin: L4_OUT_IN
            case(L3_MODE)
              2'b00: begin: L3_IN_IN
                mult_exp = '0; 
                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                  for(int L2_X=0; L2_X<4; L2_X++) begin
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(64)*L3_Y)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(64)] += out_bit_serial[L3_Y][L3_X][L2_Y][L2_X]; 
                      end
                    end
                  end
                end
              end
              2'b10: begin: L3_OUT_IN
                mult_exp = '0; 
                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                  for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                    for(int L2_X=0; L2_X<4; L2_X++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L3_Y)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_bit_serial[L3_Y][L3_X][L2_Y][L2_X]; 
                      end
                    end
                  end
                end
              end
              2'b11: begin: L3_OUT_OUT
                mult_exp = '0; 
                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                  for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                    for(int L2_X=0; L2_X<4; L2_X++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L3_Y)-:X_DIV(4)] += out_bit_serial[L3_Y][L3_X][L2_Y][L2_X]; 
                      end
                    end
                  end
                end
              end
            endcase
          end
          2'b11: begin: L4_OUT_OUT
            case(L3_MODE)
              2'b00: begin: L3_IN_IN
                mult_exp = '0; 
                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                  for(int L2_X=0; L2_X<4; L2_X++) begin
                    for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(16)*L2_X)-(X_DIV(4)*L2_Y)-:X_DIV(16)] += out_bit_serial[L3_Y][L3_X][L2_Y][L2_X]; 
                      end
                    end
                  end
                end
              end
              2'b10: begin: L3_OUT_IN
                mult_exp = '0; 
                for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                  for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                    for(int L2_X=0; L2_X<4; L2_X++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        mult_exp[(L4_OUT_WIDTH-1)-(X_DIV(4)*L2_Y)-:X_DIV(4)] += out_bit_serial[L3_Y][L3_X][L2_Y][L2_X]; 
                      end
                    end
                  end
                end
              end
              2'b11: begin: L3_OUT_OUT
                mult_exp = '0; 
                for(int L3_Y=0; L3_Y<SIZE; L3_Y++) begin
                  for(int L2_Y=0; L2_Y<4; L2_Y++) begin
                    for(int L2_X=0; L2_X<4; L2_X++) begin
                      for(int L3_X=0; L3_X<SIZE; L3_X++) begin
                        mult_exp += out_bit_serial[L3_Y][L3_X][L2_Y][L2_X]; 
                      end
                    end
                  end
                end
              end
            endcase
          end
        endcase
        `endif
      end
    endcase
  end
  
  // Accumulation of Results 
  always_ff @(posedge clk) begin
    if(rst)               accum_exp <= '0; 
    else if(tst_ac_en)    accum_exp <= accum; 
  end

  // Accumulation
  always_comb begin
    case(prec)
      4'b0000: begin
        if(accum_en) for(int x=0; x<OUTS_88; x++) begin
          accum[((Z_WIDTH*x)/OUTS_88)+:(Z_WIDTH/OUTS_88)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_88)+:WIDTH_88] + accum_exp[((Z_WIDTH*x)/OUTS_88)+:WIDTH_88+H]; 
        end
        else for(int x=0; x<OUTS_88; x++) begin
          accum[((Z_WIDTH*x)/OUTS_88)+:(Z_WIDTH/OUTS_88)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_88)+:WIDTH_88]; 
        end
      end
      4'b0010: begin
        if(accum_en) for(int x=0; x<OUTS_84; x++) begin
          accum[((Z_WIDTH*x)/OUTS_84)+:(Z_WIDTH/OUTS_84)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_84)+:WIDTH_84] + accum_exp[((Z_WIDTH*x)/OUTS_84)+:WIDTH_84+H]; 
        end
        else for(int x=0; x<OUTS_84; x++) begin
          accum[((Z_WIDTH*x)/OUTS_84)+:(Z_WIDTH/OUTS_84)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_84)+:WIDTH_84]; 
        end
      end
      4'b0011: begin
        if(accum_en) for(int x=0; x<OUTS_82; x++) begin
          accum[((Z_WIDTH*x)/OUTS_82)+:(Z_WIDTH/OUTS_82)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_82)+:WIDTH_82] + accum_exp[((Z_WIDTH*x)/OUTS_82)+:WIDTH_82+H]; 
        end
        else for(int x=0; x<OUTS_82; x++) begin
          accum[((Z_WIDTH*x)/OUTS_82)+:(Z_WIDTH/OUTS_82)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_82)+:WIDTH_82]; 
        end
      end
      4'b1010: begin
        if(accum_en) for(int x=0; x<OUTS_44; x++) begin
          accum[((Z_WIDTH*x)/OUTS_44)+:(Z_WIDTH/OUTS_44)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_44)+:WIDTH_44] + accum_exp[((Z_WIDTH*x)/OUTS_44)+:WIDTH_44+H]; 
        end
        else for(int x=0; x<OUTS_44; x++) begin
          accum[((Z_WIDTH*x)/OUTS_44)+:(Z_WIDTH/OUTS_44)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_44)+:WIDTH_44]; 
        end
      end
      4'b1111: begin
        if(accum_en) for(int x=0; x<OUTS_22; x++) begin
          accum[((Z_WIDTH*x)/OUTS_22)+:(Z_WIDTH/OUTS_22)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_22)+:WIDTH_22] + accum_exp[((Z_WIDTH*x)/OUTS_22)+:WIDTH_22+H]; 
        end
        else for(int x=0; x<OUTS_22; x++) begin
          accum[((Z_WIDTH*x)/OUTS_22)+:(Z_WIDTH/OUTS_22)]  = mult_exp[((L4_OUT_WIDTH*x)/OUTS_22)+:WIDTH_22]; 
        end
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
    logic [Z_WIDTH-1:0]  z_exp = 0;
    // step 1: check established inputs at posedge
    @(negedge clk) (!rst)
    // input processing
    |=> @(posedge clk) (1'b1, 
        z_exp = accum_exp			
    )
    |=> delay_seq(clk_to_out) |=> (z_exp == z)
  endproperty // accumulation

  property accumulation_spatial;
    logic [Z_WIDTH-1:0]  m_exp = 0;
    @(negedge clk) (!rst, 
      // $display("0.---------------------------------------------"), 
      // $display("0. exp = %h", mult_exp),
      // $display("0. out = %h", out), 
      m_exp = accum_exp
    )
    |=> @(posedge clk) (1'b1
      // $display("1.---------------------------------------------"), 
      // $display("1. exp = %h", mult_exp),
      // $display("1. out = %h", out)
    )
    |=> @(negedge clk) (1'b1,
      $display("---------------------------------------------"), 
      $display("  exp = %h", m_exp),
      $display("  z   = %h", z)
    )
    |-> (z==m_exp)
  endproperty // accumulation

  generate // Spatial or Temporal assertions
    if(!BG[1]) always @(posedge clk) assert property (accumulation_spatial);
    else       always @(posedge clk) assert property (accumulation_temporal);
  endgenerate
  
endmodule