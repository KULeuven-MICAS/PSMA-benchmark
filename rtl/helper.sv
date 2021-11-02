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
// Author:    	Ehab Ibrahim
// File Name: 	helper.sv
// Package:   	helper
// Function:  	A package containing useful functions.
//				Mainly used for estimating input/output 
//				ports and widths.
//				Allows portability accross all levels of design
//-----------------------------------------------------

package helper;
    
    function automatic int get_out_stationarity(input int rep, input bit [1:0] bg, input bit [7:0] mode, input bit [3:0] prec); 
        int base_L4, base_L3_L2, extra_L3_L2, total; 
        base_L4 = 2**(2*mode[7]) * 2**(2*mode[6]); 
        if(bg==2'b01) begin
            base_L3_L2  = 2**(2*mode[1]) * 2**(2*mode[0]); 
            extra_L3_L2 = 2**(mode[5]*(prec[1]+prec[0])) * 2**(mode[4]*(prec[3]+prec[2])); 
        end
        else begin
            base_L3_L2  = 2**(2*mode[5]) * 2**(2*mode[4]); 
            extra_L3_L2 = 2**(mode[1]*int'(prec[1]+prec[0])) * 2**int'(mode[0]*(prec[3]+prec[2])); 
        end
        total = base_L4 * base_L3_L2 * extra_L3_L2; 
        return (total>rep) ? rep : rep/total; 
    endfunction
    
    function automatic int get_outs_prec(input bit dvafs, input bit [1:0] bg, input bit [7:0] mode, input bit [3:0] prec);
        // Number of outputs per precision! 
        int mult_L3_L2, mult_L4, base_L3_L2; 
        mult_L4 = 2**(2*(!mode[7]+!mode[6])); 
        if(bg==2'b01) begin
            mult_L3_L2 = 2**(2*(!mode[1]+!mode[0]));    // L2 modifies MULT factor
            base_L3_L2 = 2**(!mode[5]*(3-1-!prec[1]-!prec[0])) * 2**(!mode[4]*(3-1-!prec[3]-!prec[2])); 
        end
        else begin
            mult_L3_L2 = 2**(2*(!mode[5]+!mode[4]));    // L3 modifies MULT factor
            if(dvafs == 0) base_L3_L2 = 2**(!mode[1]*(3-1-!prec[1]-!prec[0])) * 2**(!mode[0]*(3-1-!prec[3]-!prec[2])); 
            else           base_L3_L2 = 2**(!mode[0]*(3-1-!prec[3]-!prec[2])); 
        end
        return base_L3_L2 * mult_L3_L2 * mult_L4; 
    endfunction

    function automatic int get_width_prec(input bit dvafs, input bit [1:0] bg, input bit [7:0] mode, input bit [3:0] prec); 
        // Output width per precision! 
        int base_width, extra_L4, extra_prec, extra_L3_L2; 
        base_width = 2**(1+!prec[3]+!prec[2]) + 2**(1+!prec[1]+!prec[0]);    // width of one operation (8x8: 16-bits, 4x4: 8-bits, 2x2: 4-bits)
        extra_L4   = mode[7]*2 + mode[6]*2;                                  // For each ST axis in L4, add 2-bits (L4 is independent of precision)
        if(bg==2'b00) begin
            // In this case, precision only affects L2 unit - extra bits from precision depend on mode[3:0] only 
            if(dvafs == 0) extra_prec  = mode[1]*(3-1-!prec[1]-!prec[0]) + mode[0]*(3-1-!prec[3]-!prec[2]);
            else           extra_prec  = mode[1]*(3-1-!prec[1]-!prec[0]);
            extra_L3_L2 = mode[5]*2 + mode[4]*2;
        end
        else if (bg==2'b01) begin
            extra_prec  = mode[5]*(3-1-!prec[1]-!prec[0]) + mode[4]*(3-1-!prec[3]-!prec[2]);
            extra_L3_L2 = mode[1]*2 + mode[0]*2;
        end
        else if (bg==2'b11) begin
            extra_prec  = 3 + mode[1]*(3-1-!prec[1]-!prec[0]) + mode[0]*(3-1-!prec[3]-!prec[2]);
            extra_L3_L2 = mode[5]*2 + mode[4]*2;
        end
        return base_width + extra_prec + extra_L3_L2 + extra_L4; 
    endfunction

    function automatic int flip(input int a); 
        if(a==0||a==3) return a; 
        else if(a==1)  return 2; 
        else if(a==2)  return 1; 
        else return 0; 
    endfunction

    function automatic int max(input int a, input int b); 
        return (a > b) ? a : b;
    endfunction
    

    // NOTE: Bit Negation with ~ causes errors, use ! instead
    // BOOKMARK: Number of outputs per level 
    function automatic int get_L1_outs(input bit dvafs, input bit [1:0] mode);
        int x;
        if(dvafs==0) x = !mode[1] + !mode[0];
        else         x = !mode[1];
        return 2**x;
    endfunction
    
    function automatic int get_L2_outs(input bit dvafs, input bit [3:0] mode);
        int x;
        if(dvafs==0) x = !mode[3] + !mode[2];
        else         x = !mode[3];
        return 2**x;
    endfunction

    function automatic int get_L3_outs(input bit [1:0] mode);
        int x = !mode[1] + !mode[0];
        // L3 array size is 4x4 instead of 2x2, so we multiply x by 2 in here
        return 2**(2*x);
    endfunction

    function automatic int get_L4_outs(input bit [1:0] mode, input int size);
        int x = !mode[1] + !mode[0];
        // L4 array size can be 2x2 or 4x4, so we multiply x by size/2 in here
        return 2**((size/2)*x);
    endfunction

    function automatic int get_L4_max_outs(input bit dvafs, input bit [7:0] mode, input int size);
        int L2_outs, L3_outs, L4_outs; 
        L2_outs = get_L2_max_out(dvafs, mode[3:0]);
        L3_outs = get_L3_outs(mode[5:4]); 
        L4_outs = get_L4_outs(mode[7:6], size);
        return L2_outs*L3_outs*L4_outs; 
    endfunction

    // TODO: Replace get_L2_outs with L1_outs * L2_outs where possible 
    function automatic int get_L2_max_out(input bit dvafs, input bit [3:0] mode);
        int x;
        if(dvafs==0) x = !mode[3] + !mode[2] + !mode[1] + !mode[0];
        else         x = !mode[3] + !mode[1];
        return 2**x;
    endfunction
    
    // BOOKMARK: Output registers width 
    function automatic int get_L1_out_width(input bit dvafs, input bit bg, input bit [1:0] mode);
        int width, temp_width, max_out, cnt_1;
        
        if(dvafs==0) begin
            cnt_1 = mode[1]  + mode[0];
        end
        else begin
            cnt_1 = mode[1];
        end
        
        max_out = get_L1_outs(dvafs, mode);
        temp_width = max_out * (4+cnt_1);
        if(bg==0) begin
            width = max(8, temp_width);
        end
        else begin
            width = temp_width; 
        end
        return width; 
    endfunction

    function automatic int get_L2_out_width(input bit dvafs, input bit [1:0] bg, input bit [3:0] mode);
        int width, temp_width, L1_outs, L2_outs, L1_width, cnt_1; 
        
        if(dvafs==0) begin
            cnt_1 = mode[3]  + mode[2];
        end
        else begin
            cnt_1 = mode[3];
        end

        L1_outs    = get_L1_outs(dvafs, mode[1:0]);
        L2_outs    = get_L2_outs(dvafs, mode[3:0]);
        L1_width   = get_L1_out_width(dvafs, bg, mode[1:0]);
        temp_width = (L1_width + (L1_outs * cnt_1)) * L2_outs; 

        if(bg==2'b00) begin
            width = max(16, temp_width);
        end
        else if(bg==2'b01) begin
            width = temp_width; 
        end
        else begin
            width = temp_width + 12;
        end
        return width; 
    endfunction

    function automatic int get_L3_out_width(input bit dvafs, input bit [1:0] bg, input bit [5:0] mode);
        int width, temp_width, L2_outs, L3_outs, L2_width, cnt_1; 
        
        // DVAFS does not affect L3, only affects L2 and L1 
        cnt_1      = mode[5] + mode[4];

        L2_outs    = get_L2_max_out(dvafs, mode[3:0]);
        L3_outs    = get_L3_outs(mode[5:4]);
        L2_width   = get_L2_out_width(dvafs, bg, mode[3:0]);
        temp_width = (L2_width + (L2_outs * 2 * cnt_1)) * L3_outs;

        if(bg==2'b00) begin // Unroll BG in L2
            width = temp_width; 
        end
        else if(bg==2'b01) begin // Unroll BG in L3
            // TODO: Find a more elegant way to resolve L3_11_L2_1010 width! 
            if(mode==6'b111010) width = 72;   // In this mode, temp_width = 40-bits, which is wrong! The algorithm is correct in all other modes! 
            else                width = max(20, temp_width);
        end
        else if(bg==2'b11) begin // Unroll BG Temporally
            width = temp_width; 
        end
        return width; 
    endfunction

    function automatic int get_L4_out_width(input bit dvafs, input bit [1:0] bg, input bit [7:0] mode, input int size);
        int width, temp_width, L3_outs, L4_outs, L3_width, cnt_1; 
        
        // DVAFS does not affect L4, only affects L2 and L1 
        cnt_1      = mode[7] + mode[6];

        L3_outs    = get_L3_outs(mode[5:4]) * get_L2_max_out(dvafs, mode[3:0]);;
        L4_outs    = get_L4_outs(mode[7:6], size); 
        L3_width   = get_L3_out_width(dvafs, bg, mode[5:0]);
        width      = (L3_width + (L3_outs * (size/2) * cnt_1)) * L4_outs; 

        return width; 
    endfunction
    
    // BOOKMARK: Number of Inputs and Weights 
    function automatic int get_L1_A_inputs(input bit dvafs, input bit [1:0] mode);
        return dvafs ? 1:(mode[1] ? 2:1);
    endfunction

    function automatic int get_L1_W_inputs(input bit dvafs, input bit [1:0] mode);
        return dvafs ? 1:(mode[0] ? 2:1);
    endfunction

    function automatic int get_L2_A_inputs(input bit dvafs, input bit [3:0] mode);
        int l1_inputs, l2_inputs; 
        l2_inputs = dvafs ? 1:(mode[3] ? 2:1);
        l1_inputs = get_L1_A_inputs(dvafs, mode[1:0]);
        return l2_inputs * l1_inputs; 
    endfunction
    
    function automatic int get_L2_W_inputs(input bit dvafs, input bit [3:0] mode);
        int l1_inputs, l2_inputs; 
        l2_inputs = dvafs ? 1:(mode[2] ? 2:1);
        l1_inputs = get_L1_W_inputs(dvafs, mode[1:0]);
        return l2_inputs * l1_inputs; 
    endfunction

    function automatic int get_ARR_A_inputs(input bit [1:0] mode);
        return mode[1] ? 4:1;
    endfunction
    
    function automatic int get_ARR_W_inputs(input bit [1:0] mode);
        return mode[0] ? 4:1;
    endfunction

endpackage