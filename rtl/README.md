# RTL
This directory contains all RTL, testbenches, and some useful `.tcl` scripts for synthesis and simulation. 

## Things to note
* You may notice some files start with `tb_` while others start with `pb_`. They're basically the same testbench, but one of them is used for pre-synthesis designs (`tb`) while the other is used for post-synthesis netlist and power extraction (`pb`: PowerBench).
* `helper.sv` is a crucial package which contains lots of helpful functions for setting up localparameters in the RTL. They're mainly used to set up the port widths for all levels of design. 
* In the paper, L2 consisted of 4x4 L1 units. While in the RTL, you'll notice that L1 consists of 2x2 multipliers, and L2 consists of 2x2 L1 units. This was a legacy design that we started with, but in the end we opted for a more uniform parameter setting. **So, L1 in here is not the same as L1 in the paper!**
* `mult_2b.sv` is the lowest level (2b x 2b) multiplier, and is denoted as L1 in the paper
* Designs appended by `_mult` do not contain output registers or accumulators.
* Designs appended by `_mac` contain output registers and accumulators!
* For Bit-Serial designs, you should define the macro `BIT_SERIAL`, as it adds extra hardware (registers/counters) to the design. If you're running the `auto_framework`, this is automatically handled and you don't need to worry about it.
* `top_L2_mac.sv`, `top_L4_mult.sv`, and related files were used as intermediate designs for verification purposes. They are not used in the final benchmarked design!

## Design Hierarchy
This is the design hierarchy from the top-level down to the lowest level: 
* `pb_L4_mac.sv` -> If we're performing power simulations
* `top_L4_mac.sv`
* `L4_mac.sv`
* `L4_mult.sv`
* `L3_mult.sv`
* `L2_mult.sv`
* `L1_mult.sv` -> **NOT THE SAME AS L1 IN THE PAPER!**
* `mult_2b.sv` -> **THIS IS L1 IN THE PAPER!**
* `counter.sv`
* `macro_utils.sv`
* `helper.sv`

## Parameters
In this section, we go through all relevant parameters and their accepted values: 
1. `HEADROOM`: Amount of headroom bits for each output in the accumulator registers. This was always set to `4` in the paper's benchmark.
2. `L4/L3/L2_MODE`: Controls whether each layer has Input Sharing (IS), Hybrid Sharing (HS), or Output Sharing (OS). Accepted values: 
    * `00`: IS
    * `10`: HS
    * `11`: OS
3. `BG`: Controls whether the design has its Bit-Groups unrolled at L2, L3, or temporally a.k.a Bit-Serial (BS)
    * `00`: BG in L2
    * `01`: BG in L3
    * `11`: BG is temporal (BS)
4. `DVAFS`: Controls if the design is Fully Unrolled (FU) or Sub-Word Unrolled (SWU)
    * `0`: FU design
    * `1`: SWU design
5. `prec`: Controls the precision of the PSMA. (Note that this is not a parameter, it can be changed during run-time)
    * `0000`: 8b x 8b
    * `0010`: 8b x 4b
    * `0011`: 8b x 2b
    * `1010`: 4b x 4b
    * `1111`: 2b x 2b  