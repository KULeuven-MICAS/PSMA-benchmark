#!/usr/bin/env python
# coding: utf-8
# Copyright 2021 MICAS, KU LEUVEN
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# -----------------------------------------------------
# Author:    Ehab Ibrahim
# Function:  Automatic Framework for MAC benchmarking
#            Synthesize - Power Simulation - Power Extraction
#            Extract area and power breakdown in breakdown dir
# -----------------------------------------------------
from imports import *
import config as CFG

# IMPORTANT NOTE:
#   DVAFS_0 OR DVAFS = False -> FU Designs
#   DVAFS_1 OR DVAFS = True -> SWU Designs
DVAFS = False

# Create logger object for logging purposes
logger = logging.getLogger("auto_L4")

# start time of script execution
start_time = time.time()

# Clock periods to be synthesized in 'ns'
CLK_LIST = [1.00, 5.00]

# Precisions to be tested
# Supported precisions are:
#       8x8 (0000)
#       8x4 (0010)
#       8x2 (0011)
#       4x4 (1010)
#       2x2 (1111)
if not DVAFS:
    # FU precision list
    PREC = ["0000", "0010", "0011", "1010", "1111"]
else:
    # SWU precision list
    PREC = ["0000", "1010", "1111"]

# Create a new list of tuples with the product of (prec, clk)
PREC_LIST = list(product(PREC, CLK_LIST))


def main():

    logger.info("Starting Script!")

    # Populate temporary directory at CFG.TMP_DIR
    CFG.populate_tmp_dir(CLK_LIST)

    # Create MultiProcessing pool with 4 threads for synthesis
    # Each MP thread spawns an 8-thread process (controlled by syn_L4_mac)
    pool = mp.Pool(4)

    # Synthesize designs in CFG.DESIGN_NAMES list
    pool.starmap(CFG.synthesis, product(CLK_LIST, CFG.DESIGN_NAMES))
    logger.info(f"Synthesized all designs! Starting power simulations")

    pool.close()
    pool.join()

    # Create new Multi-Processing pool with 24 threads for power simulations
    pool = mp.Pool(24)

    pool.starmap(CFG.power_simulation, product(PREC_LIST, CFG.DESIGN_NAMES))
    logger.info("Finished Power Simulations!")

    ############ Power and Area Breakdown ############
    pool.starmap(CFG.generate_breakdown_df, product(CLK_LIST, [PREC], [DVAFS]))

    pool.close()
    pool.join()

    CFG.cleanup(CFG.TMP_DIR)

    logger.info(f"Log messages saved to ./{log_file}")
    end_time = round(time.time() - start_time)
    end_time = timedelta(seconds=end_time)
    logger.info(f"THE SCRIPT TOOK ({end_time}) TO FINISH")


# To handle exceptions in a clean way
if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        # Handle KeyboardInterrupt
        # Kill all running processes and delete TMP directory
        logger.warning("Interrupted - Cleaning up and exiting")
        try:
            os.system("killall genus")
            os.system("killall vsim")
            os.system("killall sed")
            CFG.cleanup(CFG.TMP_DIR)
            sys.exit(0)
        except Exception as E:
            logger.warning(f"Couldn't exit normally - faced Exception: {E}")
            os._exit(0)
    except OSError as OSE:
        logger.warning(f"OSError: Exception: {OSE}")
        try:
            os.system("killall genus")
            os.system("killall vsim")
            os.system("killall sed")
            CFG.cleanup(CFG.TMP_DIR)
            sys.exit(0)
        except Exception as E:
            logger.warning(f"Couldn't exit normally - faced Exception: {E}")
            os._exit(0)
