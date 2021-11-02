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
// File Name: mult_2b.sv
// Design:    mult_2b
// Function:  Combinational 2bx2b multiplier unit
//-----------------------------------------------------

module mult_2b (w, a, out); 

    input  [1:0] w, a; 
    
    output [3:0] out;
    
    assign out = $unsigned(a) * $unsigned(w); 
    
endmodule