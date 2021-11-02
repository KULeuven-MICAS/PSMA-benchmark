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
// File Name: macro_utils.sv
// Function:  Useful macros to avoid code repitition
//-----------------------------------------------------

// Macros for L2_mac
`define accum_out_16_utils(NAME, WIDTH) \
    NAME[1 *(WIDTH)-1 -: WIDTH] = mult[(1 *WIDTH-H)-1 -: WIDTH-H] + z[1 *(WIDTH)-1 -: WIDTH]; \
    NAME[2 *(WIDTH)-1 -: WIDTH] = mult[(2 *WIDTH-H)-1 -: WIDTH-H] + z[2 *(WIDTH)-1 -: WIDTH]; \
    NAME[3 *(WIDTH)-1 -: WIDTH] = mult[(3 *WIDTH-H)-1 -: WIDTH-H] + z[3 *(WIDTH)-1 -: WIDTH]; \
    NAME[4 *(WIDTH)-1 -: WIDTH] = mult[(4 *WIDTH-H)-1 -: WIDTH-H] + z[4 *(WIDTH)-1 -: WIDTH]; \
    NAME[5 *(WIDTH)-1 -: WIDTH] = mult[(5 *WIDTH-H)-1 -: WIDTH-H] + z[5 *(WIDTH)-1 -: WIDTH]; \
    NAME[6 *(WIDTH)-1 -: WIDTH] = mult[(6 *WIDTH-H)-1 -: WIDTH-H] + z[6 *(WIDTH)-1 -: WIDTH]; \
    NAME[7 *(WIDTH)-1 -: WIDTH] = mult[(7 *WIDTH-H)-1 -: WIDTH-H] + z[7 *(WIDTH)-1 -: WIDTH]; \
    NAME[8 *(WIDTH)-1 -: WIDTH] = mult[(8 *WIDTH-H)-1 -: WIDTH-H] + z[8 *(WIDTH)-1 -: WIDTH]; \
    NAME[9 *(WIDTH)-1 -: WIDTH] = mult[(9 *WIDTH-H)-1 -: WIDTH-H] + z[9 *(WIDTH)-1 -: WIDTH]; \
    NAME[10*(WIDTH)-1 -: WIDTH] = mult[(10*WIDTH-H)-1 -: WIDTH-H] + z[10*(WIDTH)-1 -: WIDTH]; \
    NAME[11*(WIDTH)-1 -: WIDTH] = mult[(11*WIDTH-H)-1 -: WIDTH-H] + z[11*(WIDTH)-1 -: WIDTH]; \
    NAME[12*(WIDTH)-1 -: WIDTH] = mult[(12*WIDTH-H)-1 -: WIDTH-H] + z[12*(WIDTH)-1 -: WIDTH]; \
    NAME[13*(WIDTH)-1 -: WIDTH] = mult[(13*WIDTH-H)-1 -: WIDTH-H] + z[13*(WIDTH)-1 -: WIDTH]; \
    NAME[14*(WIDTH)-1 -: WIDTH] = mult[(14*WIDTH-H)-1 -: WIDTH-H] + z[14*(WIDTH)-1 -: WIDTH]; \
    NAME[15*(WIDTH)-1 -: WIDTH] = mult[(15*WIDTH-H)-1 -: WIDTH-H] + z[15*(WIDTH)-1 -: WIDTH]; \
    NAME[16*(WIDTH)-1 -: WIDTH] = mult[(16*WIDTH-H)-1 -: WIDTH-H] + z[16*(WIDTH)-1 -: WIDTH];

`define accum_out_8_utils(NAME, WIDTH) \
    NAME[1 *(WIDTH)-1 -: WIDTH] = mult[(1 *WIDTH-H)-1 -: WIDTH-H] + z[1 *(WIDTH)-1 -: WIDTH]; \
    NAME[2 *(WIDTH)-1 -: WIDTH] = mult[(2 *WIDTH-H)-1 -: WIDTH-H] + z[2 *(WIDTH)-1 -: WIDTH]; \
    NAME[3 *(WIDTH)-1 -: WIDTH] = mult[(3 *WIDTH-H)-1 -: WIDTH-H] + z[3 *(WIDTH)-1 -: WIDTH]; \
    NAME[4 *(WIDTH)-1 -: WIDTH] = mult[(4 *WIDTH-H)-1 -: WIDTH-H] + z[4 *(WIDTH)-1 -: WIDTH]; \
    NAME[5 *(WIDTH)-1 -: WIDTH] = mult[(5 *WIDTH-H)-1 -: WIDTH-H] + z[5 *(WIDTH)-1 -: WIDTH]; \
    NAME[6 *(WIDTH)-1 -: WIDTH] = mult[(6 *WIDTH-H)-1 -: WIDTH-H] + z[6 *(WIDTH)-1 -: WIDTH]; \
    NAME[7 *(WIDTH)-1 -: WIDTH] = mult[(7 *WIDTH-H)-1 -: WIDTH-H] + z[7 *(WIDTH)-1 -: WIDTH]; \
    NAME[8 *(WIDTH)-1 -: WIDTH] = mult[(8 *WIDTH-H)-1 -: WIDTH-H] + z[8 *(WIDTH)-1 -: WIDTH]; 

`define accum_out_4_utils(NAME, WIDTH) \
    NAME[0+:WIDTH] = mult[0+:(W/4)]       + z[0+:WIDTH]; \
    NAME[Q+:WIDTH] = mult[(W/4)+:(W/4)]   + z[Q+:WIDTH]; \
    NAME[M+:WIDTH] = mult[(W/2)+:(W/4)]   + z[M+:WIDTH]; \
    NAME[T+:WIDTH] = mult[(3*W/4)+:(W/4)] + z[T+:WIDTH]; 

`define accum_out_2_utils(NAME, WIDTH) \
    NAME[0+:WIDTH] = mult[0+:(W/2)]       + z[0+:WIDTH]; \
    NAME[M+:WIDTH] = mult[(W/2)+:(W/2)]   + z[M+:WIDTH]; 
