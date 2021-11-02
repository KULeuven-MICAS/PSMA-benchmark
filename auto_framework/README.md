# Automatic Benchmarking Framework
Our paper benchmarked 72 different PSMAs. To make the benchmarking process as streamlined as possible, we automated the benchmarking process. This folder consists of all python scripts used for automation.

## Main function
The scripts in here provide two main utilities: 
1. Automate the synthesis -> simulation -> power extraction process
2. Read the breakdown report and plot the results

Plotting scripts are named as `plotting`, and all the rest of the scripts are the brains of the framework

## Features
* Parameterized: You can choose which designs you would like to benchmark, and at which clock periods
* Multi-threaded: To quickly benchmark all designs covered by our taxonomy
* Logs: A logger object is created which logs all important events in the process

## Framework Structure
* `auto_framework.py`: The main high level script. 
    * Handles the multi-processing pools
    * Sets the clock periods to synthesize
    * Chooses the precisions to run
* `config.py`: Contains most other parameters and function definitions
    * Main project directory
    * Technology node library files
    * Designs to benchmark
    * Important directories
    * **All high level operation functions**
* `design_cfg.py`: A dictionary which contains the parameters of all benchmarked designs
* `imports.py`: Contains all relevant imports and sets up the logger object

## Under the hood
In a nutshell, the common synthesis and simulation scripts are the `.tcl` scripts which reside in the [RTL folder](../rtl). The `.tcl` scripts expects some parameters to be set (can be found [here](../rtl/README.md)). To set these parameters, the `auto_framework` writes intermediate `tcl` files which are passed to Questa or Genus before the common `tcl` scripts in RTL. For more information, you can refer to `synthesis()` and `power_simulation()` functions in [`config.py`](config.py).

The general flow is as follows: 
1. Create a temporary directory to hold all intermediate results
2. Synthesize the designs using Genus, generate synthesis report
3. Perform power simulations using Questa, generate VCD files
4. Read VCD files using Genus, generate power reports
5. Parse synthesis and power reports and generate breakdown report (using regex and pandas)
6. Plot breakdown reports (requires power to energy conversion, which is done by plotting functions)

## License
All python scripts are licensed under the [Apache 2.0 license](LICENSE).