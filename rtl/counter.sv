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
// File Name: counter.sv
// Design:    counter
// Function:  Counter for bit serial designs; 
//            Issues a strobe (enable) signal when the 
//            counter is equal to the input "count" value
//-----------------------------------------------------

module counter(clk, rst, count, out); 

    input       clk, rst; 
    input [3:0] count; 
    output      out;
    
    logic [3:0] cnt; 
    logic [3:0] cnt_next; 
    logic       out_tmp; 
    
    always @(posedge clk) begin
        if(rst) begin
            out_tmp <= 1'b1;
            cnt <= '0; 
        end
        else if(cnt == count) begin
            cnt <= '0;
            out_tmp <= 1'b1;
        end
        else begin
            cnt <= cnt_next;
            out_tmp <= 1'b0; 
        end
    end
    
    assign cnt_next = cnt + 1'b1; 
    assign out = out_tmp; 
    
endmodule