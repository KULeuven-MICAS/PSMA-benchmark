# Taxonomy and Benchmarking of Precision-Scalable MAC Arrays for DNN Dataflows

This repository contains supplementary materials for the benchmarking study of our paper: 

[Ibrahim, Ehab M., Linyan Mei, and Marian Verhelst. "Survey and Benchmarking of Precision-Scalable MAC Arrays for Embedded DNN Processing." arXiv preprint arXiv:2108.04773 (2021).](https://arxiv.org/abs/2108.04773)

## Abstract
Reduced-precision and variable-precision multiply-accumulate (MAC) operations provide opportunities to significantly improve energy efficiency and throughput of DNN accelerators with no/limited algorithmic performance loss, paving a way towards deploying AI applications on resource-constraint edge devices. Accordingly, various precision-scalable MAC array (PSMA) architectures were recently proposed. However, it is difficult to make a fair comparison between those alternatives, as each proposed PSMA is demonstrated in different systems with different technologies. This work aims to provide a clear view on the design space of PSMA and offer insights for selecting the optimal architectures based on designers' needs. First, we introduce a precision-enhanced for-loop representation for DNN dataflows. Next, we use this new representation towards a comprehensive PSMA taxonomy, capable to systematically cover most prominent state-of-the-art PSMAs, as well as uncover new PSMA architectures. Following that, we build a highly parameterized PSMA template that can be design-time configured into a huge subset of the design space spanned by the taxonomy. This allows to fairly and thoroughly benchmark 72 different PSMA architectures. We perform such studies in 28nm technology targeting run-time precision scalability from 8 to 2 bits, operating at 200 MHz and 1 GHz. Analyzing resulting energy efficiency and area breakdowns reveals key design guidelines for PSMA architectures.

## Introduction
In this study, **72 different Precision-Scalable MAC arrays (PSMA)** were benchmarked. All 72 designs were generated from the same RTL, so as you can tell, **the RTL is very (very) parameterizable**. To make the benchmarking process as seamless as possible, an **automatic benchmark framework** is also introduced in this repository. This auto framework is multi-threaded, and handles the whole benchmark flow, including (synthesis - post synthesis simulation - power and area extraction), and in the end it generates a detailed breakdown of the power/area of each module of the design.

This repository holds all RTL, synthesis, automation, and plotting scripts used in our study. All RTL and testbenches are written in `SystemVerilog`, and automation scripts are a combination of `tcl` and `Python` scripts. Plotting is handled in `Python` using a combination of `pandas`, `matplotlib`, and `seaborn` libraries.

## Pre-requisites
### Automatic Framework
* python 3.6+
* numpy
* pandas
* matplotlib
* seaborn
### Synthesis and Simulation
* A beast of a server
* Lots of memory (for generated VCD files)
* QuestaSim -> Simulation
* Cadence Genus (legacy ui) -> Synthesis

Please note that it's possible to use other tools, but this would require changing the simulation/synthesis scripts to support the new tools.

## Project Structure
* `auto_framework`: The automatic benchmarking framework + plotting scripts. More information can be found in [auto_framework's README](auto_framework/README.md)
* `constraints`: Contains some `.sdc` files used during synthesis
* `lib`: This directory should be used as a symbolic link to the technology node used in synthesis. For reference, you can create a symbolic link in a linux environment using: 
```bash
ln -s <PATH_TO_LIBRARY> <PATH_TO_THIS_REPOSITORY>/lib/
```
* `results`: Contains the results from our benchmark run. Right now, it contains the breakdowns and figures used in our paper for clock frequencies of `1.00 ns` and `5.00 ns`, for both FU and SWU designs
* `rtl`: Contains the RTL and Testbenches, as well as some useful `.tcl` scripts. More information can be found in [RTL's README](rtl/README.md)

## Before we start
This study was conducted over the span of 1+ year, and so you may find some naming deviations from the paper. The most notable differences are: 
* Fully Unrolling (FU) and Sub-Word Unrolling (SWU) are called DVAFS_0 and DVAFS_1 respectively
* In the paper, L2 consisted of 4x4 L1 units, and each L1 unit is a 2b multiplier. While in the RTL, you'll notice that L1 consists of 2x2 2b multipliers, and L2 consists of 2x2 L1 units. This was a legacy design that we started with, but in the end we opted for a more uniform parameter setting. **So, L1 in RTL is not the same as L1 in the paper!** But other than L1, L2/L3/L4 are consistent between the code and paper.

## Quickstart Guide
Before you can use the `auto_framework`, you MUST first go to [`config.py`](auto_framework/config.py) and set the `LIB_DB` and `LIB_V` variables to the correct `.lib` and `.v` technology files. You can also quickly check other parameters over there and change them as you see fit. For instance, you can set the `LOCAL_DIR` variable to a location with lots of free space, as this is where the `.vcd` files will be dumped. With that out of the way: 
```
cd auto_framework
python auto_framework.py
```
Have a good night's sleep (or 2), and hopefully you'll find your new results in the [breakdown](results/breakdown/) folder

## Plotting Results
All relevant plotting functions reside in [plotting_functions.py](auto_framework/plotting_functions.py). You can also run the plotting functions from a [Jupyter notebook](auto_framework/plotting.ipynb) as it gave some room for experimentation and re-iteration compared to python scripts.

## License
All RTL designs are licensed under the [Solderpad Hardware License](LICENSE.md), while all python scripts are licensed under the [Apache license version 2.0](auto_framework/LICENSE).