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
# Author:   Ehab Ibrahim
# Function: Configuration parameters and function definitions
#           for Auto Framework - contains functions for generating
#           TCL scripts, synthesizing, power simulation, and
#           report extraction
# -----------------------------------------------------

from imports import *
from design_cfg import DESIGN_CFG

logger = logging.getLogger("auto_L4")

# IMPORTANT NOTE: 
#   Lx_00 -> IS at layer x
#   Lx_10 -> HS at layer x
#   Lx_11 -> OS at layer x
#   DVAFS_0 OR DVAFS = False -> FU Designs
#   DVAFS_1 OR DVAFS = True -> SWU Designs
# SWU designs only support symmetrical multiplications, and the list
# of tested precisions is set in `auto_framework.py`. Make sure to 
# DVAFS variable in both scripts are matched, else you might run 
# into weird issues

DVAFS = False
DESIGN = "top_L4_mac"
# HEADROOM is number of bits used for accumulation headroom in the output register
HEADROOM = 4
# RST is the number of iterations of the power simulation. Each iteration starts
# with a reset signal. Total number of simulation cycles is (RST * REP)
RST = 1
# REP is the number of clock cycles used in the power simulation per iteration
REP = 4096

if not DVAFS:
    # FU Designs
    DESIGN_NAMES = ["BG_L2_L4_00_L3_00_L2_00_DVAFS_0", "BG_L2_L4_00_L3_00_L2_10_DVAFS_0", "BG_L2_L4_00_L3_00_L2_11_DVAFS_0",
                    "BG_L2_L4_00_L3_10_L2_00_DVAFS_0", "BG_L2_L4_00_L3_10_L2_10_DVAFS_0", "BG_L2_L4_00_L3_10_L2_11_DVAFS_0",
                    "BG_L2_L4_00_L3_11_L2_00_DVAFS_0", "BG_L2_L4_00_L3_11_L2_10_DVAFS_0", "BITFUSION",

                    "BG_L2_L4_10_L3_00_L2_00_DVAFS_0", "BG_L2_L4_10_L3_00_L2_10_DVAFS_0", "BG_L2_L4_10_L3_00_L2_11_DVAFS_0",
                    "BG_L2_L4_10_L3_10_L2_00_DVAFS_0", "BG_L2_L4_10_L3_10_L2_10_DVAFS_0", "BG_L2_L4_10_L3_10_L2_11_DVAFS_0",
                    "BG_L2_L4_10_L3_11_L2_00_DVAFS_0", "BG_L2_L4_10_L3_11_L2_10_DVAFS_0", "BG_L2_L4_10_L3_11_L2_11_DVAFS_0",

                    "BG_L2_L4_11_L3_00_L2_00_DVAFS_0", "BG_L2_L4_11_L3_00_L2_10_DVAFS_0", "BG_L2_L4_11_L3_00_L2_11_DVAFS_0",
                    "BG_L2_L4_11_L3_10_L2_00_DVAFS_0", "BG_L2_L4_11_L3_10_L2_10_DVAFS_0", "BG_L2_L4_11_L3_10_L2_11_DVAFS_0",
                    "BG_L2_L4_11_L3_11_L2_00_DVAFS_0", "BG_L2_L4_11_L3_11_L2_10_DVAFS_0", "BG_L2_L4_11_L3_11_L2_11_DVAFS_0",

                    "BG_L3_L4_00_L3_00_L2_10_DVAFS_0", "BG_L3_L4_00_L3_00_L2_11_DVAFS_0",
                    "BG_L3_L4_00_L3_10_L2_10_DVAFS_0", "BG_L3_L4_00_L3_10_L2_11_DVAFS_0",
                    "BG_L3_L4_00_L3_11_L2_10_DVAFS_0", "BITBLADE",

                    "BG_L3_L4_10_L3_00_L2_10_DVAFS_0", "BG_L3_L4_10_L3_00_L2_11_DVAFS_0",
                    "BG_L3_L4_10_L3_10_L2_10_DVAFS_0", "BG_L3_L4_10_L3_10_L2_11_DVAFS_0",
                    "BG_L3_L4_10_L3_11_L2_10_DVAFS_0", "BG_L3_L4_10_L3_11_L2_11_DVAFS_0",

                    "BG_L3_L4_11_L3_00_L2_10_DVAFS_0", "BG_L3_L4_11_L3_00_L2_11_DVAFS_0",
                    "BG_L3_L4_11_L3_10_L2_10_DVAFS_0", "BG_L3_L4_11_L3_10_L2_11_DVAFS_0",
                    "BG_L3_L4_11_L3_11_L2_10_DVAFS_0", "BG_L3_L4_11_L3_11_L2_11_DVAFS_0",

                    "LOOM",                            "BG_BS_L4_00_L3_10_L2_11_DVAFS_0", "BG_BS_L4_00_L3_11_L2_11_DVAFS_0",

                    "BG_BS_L4_10_L3_00_L2_11_DVAFS_0", "BG_BS_L4_10_L3_10_L2_11_DVAFS_0", "BG_BS_L4_10_L3_11_L2_11_DVAFS_0",

                    "BG_BS_L4_11_L3_00_L2_11_DVAFS_0", "BG_BS_L4_11_L3_10_L2_11_DVAFS_0", "BG_BS_L4_11_L3_11_L2_11_DVAFS_0"]
else:
    # SWU Designs
    DESIGN_NAMES = ["BG_L2_L4_00_L3_00_L2_00_DVAFS_1", "BG_L2_L4_00_L3_00_L2_11_DVAFS_1",
                    "BG_L2_L4_00_L3_10_L2_00_DVAFS_1", "BG_L2_L4_00_L3_10_L2_11_DVAFS_1",
                    "BG_L2_L4_00_L3_11_L2_00_DVAFS_1", "BG_L2_L4_00_L3_11_L2_11_DVAFS_1",
                    "BG_L2_L4_10_L3_00_L2_00_DVAFS_1", "BG_L2_L4_10_L3_00_L2_11_DVAFS_1",
                    "BG_L2_L4_10_L3_10_L2_00_DVAFS_1", "BG_L2_L4_10_L3_10_L2_11_DVAFS_1",
                    "BG_L2_L4_10_L3_11_L2_00_DVAFS_1", "BG_L2_L4_10_L3_11_L2_11_DVAFS_1",
                    "BG_L2_L4_11_L3_00_L2_00_DVAFS_1", "BG_L2_L4_11_L3_00_L2_11_DVAFS_1",
                    "BG_L2_L4_11_L3_10_L2_00_DVAFS_1", "BG_L2_L4_11_L3_10_L2_11_DVAFS_1",
                    "BG_L2_L4_11_L3_11_L2_00_DVAFS_1", "BG_L2_L4_11_L3_11_L2_11_DVAFS_1"]

# Directories
# MAIN_DIR is the parent directory of this repository. Assuming we're running this
# script from `auto_framework` directory, then MAIN_DIR is up one directory
MAIN_DIR = ".."
# LOCAL_DIR is where we will dump all the VCD files. It has to be a location
# with LOTS of free space, especially if you run with multi-processing
LOCAL_DIR = ".."
RTL_DIR = f"{MAIN_DIR}/rtl"
# Library file paths
# Here, I assume a symbolic link is created in MAIN_DIR/lib to the technology files
# Uncomment the next lines, and point to the correct `.lib` and `.v` files
LIB_DB = f"{MAIN_DIR}/lib/...../.lib"
LIB_V = f"{MAIN_DIR}/lib/...../.v"
# Some timing constraints were set to `prec` signals in `constraints` directory
SDC_PATH = f"{MAIN_DIR}/constraints"
# TMP directory which stores all intermediate results
TMP_DIR = f"{LOCAL_DIR}/TMP"
# Directory of the final results
RESULT_DIR = f"{MAIN_DIR}/results"
# Some pointers to useful files
HELPER_FILE = f"{RTL_DIR}/helper.sv"
SYN_FILE_L4 = f"{RTL_DIR}/syn_L4_mac.tcl"
PB_FILE_L4 = f"{RTL_DIR}/pb_L4_mac.sv"
SIM_PB_L4 = f"{RTL_DIR}/sim_pb_L4_mac.tcl"



# Breakdown Variables
# Extracted powers will be stored into a dataframe with KEYS_POWER keys
KEYS_POWER = [
    "top",
    "mac",
    "L4",
    "L3",
    "L2",
    "L4_tree",
    "L3_tree",
    "L2_tree",
    "mult_2x2",
    "count",
    "out_reg",
    "pipe_reg",
    "in_reg",
    "accum",
]
# Extracted areas will be stored into a dataframe with KEYS_POWER keys
KEYS_AREA = [
    "top",
    "mac",
    "mult",
    "mult_2x2",
    "count",
    "out_reg",
    "in_reg",
    "others",
    "seq",
    "comb",
]
PREC_DICT = {"0000": "8x8", "0010": "8x4", "0011": "8x2", "1010": "4x4", "1111": "2x2"}

############# Function Definitions ##################

############# SYNTHESIS
def generate_syn_setup_script(export, des, report, clk_8, clk_4, clk_2):
    with open("syn_setup.tcl", "w") as syn_fp:
        syn_fp.write(
            f"""########### INFO ###########
set AUTO         yes

set DESIGN_NAME  {des}
set SDC_MODE     {DESIGN_CFG[des]["SDC_MODE"]}
set DESIGN       {DESIGN}

set HEADROOM     {HEADROOM}
set L4_MODE      {DESIGN_CFG[des]["L4_MODE"]}
set L3_MODE      {DESIGN_CFG[des]["L3_MODE"]}
set L2_MODE      {DESIGN_CFG[des]["L2_MODE"]}
set BG           {DESIGN_CFG[des]["BG"]}
set DVAFS        {DESIGN_CFG[des]["DVAFS"]}

set CLK_8B       {clk_8:3.2f}
set CLK_4B       {clk_4:3.2f}
set CLK_2B       {clk_2:3.2f}

set LIB_DB       {LIB_DB}

set SDC_PATH     {SDC_PATH}
set EXPORT_PATH  {export}
set REPORT_FILE  {report}
set RTL_PATH     {RTL_DIR}

"""
        )


def generate_PB_setup_script(export, des, prec, clk, rst=RST, rep=REP):
    with open(f"PB_setup_{prec}_{des}.tcl", "w") as power_sim_fp:
        power_sim_fp.write(
            f"""########### INFO ###########
set AUTO         yes

set EXPORT_PATH  {export}
set LIB_V        {LIB_V}

set V_FILE       {export}/post.v
set SDF_FILE     {export}/post.sdf
set PB_FILE      {PB_FILE_L4}
set HELPER       {HELPER_FILE}

set TEST         0
set PRECISION    {prec}
set CLK_PERIOD   {clk:3.2f}
set HEADROOM     {HEADROOM}
set L4_MODE      {DESIGN_CFG[des]["L4_MODE"]}
set L3_MODE      {DESIGN_CFG[des]["L3_MODE"]}
set L2_MODE      {DESIGN_CFG[des]["L2_MODE"]}
set BG           {DESIGN_CFG[des]["BG"]}
set DVAFS        {DESIGN_CFG[des]["DVAFS"]}
set VCD_FILE     dump_{prec}_clk{clk:3.2f}_{des}.vcd
set RST          {rst}
set REP          {rep}

set LIB_DB       {LIB_DB}

set SDC_PATH     {SDC_PATH}

"""
        )


def generate_power_setup_script(export, prec, clk, des, report):
    with open(f"power_{prec}_{des}.tcl", "w") as power_fp:
        power_fp.write(
            f"""################# LIBRARY #################

set_attribute library {LIB_DB}

################# DESIGN ##################

set_attribute lp_power_analysis_effort high

read_hdl -library work {export}/post.v

elaborate {DESIGN}

############### ANALYZE VCD ###############

read_vcd -static dump_{prec}_clk{clk:3.2f}_{des}.vcd

############### REPORT POWER ##############

echo "\\n############### POWER - {prec} SUMMARY\\nSimulated at {clk:3.2f} clock period.\\n" > {report}
report power -verbose >> {report}

echo "\\n############### POWER - {prec} DETAILS\\nSimulated at {clk:3.2f} clock period.\\n" >> {report}
report power -flat -sort dynamic >> {report}

# Clean-up
delete_obj /designs/*

"""
        )


############# Data Extration
def area_extract(dict_in, file_in, design):
    for line in file_in:
        dict_in[design]["top"] += re.findall(r"^top_L4_mac\s+(?:\d+\s+){3}(\d+)", line)
        dict_in[design]["mac"] += re.findall(
            r"^.+L4\s+L4_mac\w+\s+(?:\d+\s+){3}(\d+)", line
        )
        dict_in[design]["mult"] += re.findall(
            r"^.+L4_mult\s+L4_mult\w+\s+(?:\d+\s+){3}(\d+)", line
        )
        dict_in[design]["mult_2x2"] += re.findall(
            r"^.+mult_2b.+mult_2b\w+\s+(?:\d+\s+){3}(\d+)", line
        )
        dict_in[design]["count"] += re.findall(
            r"^.+count_\w+(?:\s+\w+){4}\s+(\d+)", line
        )
        dict_in[design]["out_reg"] += re.findall(r"^sequential\s+\d+\s+(\d+)", line)


def power_extract(dict_in, file_in, prec, design):
    for line in file_in:
        dict_in[prec][design]["top"] += re.findall(
            r"^top_L4_mac\s+\d+\s+(?:\d+\.\d+\s+){4}(\d+\.\d+)", line
        )
        dict_in[prec][design]["mac"] += re.findall(
            r"^\s+L4\s+\d+\s+(?:\d+\.\d+\s+){4}(\d+\.\d+)", line
        )
        dict_in[prec][design]["L4"] += re.findall(
            r"^\s+L4_mult\s+\d+\s+(?:\d+\.\d+\s+){4}(\d+\.\d+)", line
        )
        dict_in[prec][design]["mult_2x2"] += re.findall(
            r"^\s+mult_2b.+mult\s+\d+\s+(?:\d+\.\d+\s+){4}(\d+\.\d+)", line
        )
        dict_in[prec][design]["L2"] += re.findall(
            r"^\s+L2_mult.+L2\s+\d+\s+(?:\d+\.\d+\s+){4}(\d+\.\d+)", line
        )
        dict_in[prec][design]["L3"] += re.findall(
            r"^\s+L3_mult.+L3\s+\d+\s+(?:\d+\.\d+\s+){4}(\d+\.\d+)", line
        )
        dict_in[prec][design]["count"] += re.findall(
            r"^.+count_\w+\s+\d+\s+(?:\d+\.\d+\s+){4}(\d+\.\d+)", line
        )
        dict_in[prec][design]["out_reg"] += re.findall(
            r"^L4/\w*_reg\[\d*\]\s*\d*\.\d*\s*\d*\.\d*\s*(\d*\.\d*)", line
        )
        dict_in[prec][design]["pipe_reg"] += re.findall(
            r"^L4/\w*\.\.\w*(?:shift|/out)_reg\[\d*\]\s*\d*\.\d*\s*\d*\.\d*\s*(\d*\.\d*)",
            line,
        )
        dict_in[prec][design]["in_reg"] += re.findall(
            r"^\w_reg_reg(?:\[.*\]){5}\s*(?:\d*\.\d*\s*){2}(\d*\.\d*)", line
        )


def get_extracted_dataframes(mapping, prec_list):
    # Initialize Areas and Powers Dictionaries - to be able to append to their lists later!
    precisions = [PREC_DICT[prec] for prec in prec_list]
    areas = {d: {k: [] for k in KEYS_AREA} for d in DESIGN_NAMES}
    powers = {
        p: {d: {k: [] for k in KEYS_POWER} for d in DESIGN_NAMES} for p in precisions
    }
    # Extract Area and Power from Report
    for d in DESIGN_NAMES:
        with open(f"{RESULT_DIR}/{d}/{mapping}/report_syn.rpt") as report:
            area_extract(dict_in=areas, file_in=report, design=d)
        for prec in prec_list:
            with open(f"{RESULT_DIR}/{d}/{mapping}/report_power_{prec}.rpt") as report:
                power_extract(
                    dict_in=powers, file_in=report, prec=PREC_DICT[prec], design=d
                )

    # Change area values to int, and sum up needed lists
    for d in DESIGN_NAMES:
        for k in KEYS_AREA:
            areas[d][k] = sum(int(i) for i in areas[d][k])
        areas[d]["in_reg"] = areas[d]["top"] - areas[d]["mac"]
        areas[d]["others"] = (
            areas[d]["mac"] - areas[d]["mult_2x2"] - areas[d]["out_reg"]
        )
        areas[d]["seq"] = areas[d]["in_reg"] + areas[d]["out_reg"]
        areas[d]["comb"] = areas[d]["top"] - areas[d]["seq"]

    # Change power values to float, and sum up needed lists
    for p in precisions:
        for d in DESIGN_NAMES:
            for k in KEYS_POWER:
                powers[p][d][k] = round(sum(float(i) for i in powers[p][d][k]), 4)
            powers[p][d]["accum"] = (
                powers[p][d]["top"]
                - powers[p][d]["in_reg"]
                - powers[p][d]["L4"]
                - powers[p][d]["out_reg"]
            )
            powers[p][d]["accum"] = round(powers[p][d]["accum"], 4)
            powers[p][d]["L4_tree"] = powers[p][d]["L4"] - powers[p][d]["L3"]
            powers[p][d]["L3_tree"] = powers[p][d]["L3"] - powers[p][d]["L2"]
            powers[p][d]["L2_tree"] = (
                powers[p][d]["L2"] - powers[p][d]["mult_2x2"] - powers[p][d]["pipe_reg"]
            )
            powers[p][d]["L4_tree"] = round(powers[p][d]["L4_tree"], 4)
            powers[p][d]["L3_tree"] = round(powers[p][d]["L3_tree"], 4)
            powers[p][d]["L2_tree"] = round(powers[p][d]["L2_tree"], 4)

    # Convert to Pandas Dataframes
    power_df = (
        pd.DataFrame.from_dict(
            {(p, d): powers[p][d] for p in precisions for d in DESIGN_NAMES},
            orient="index",
        )
        .sort_index(level=0, ascending=False)
        .reindex(DESIGN_NAMES, level=1)
        / 1e6
    )
    area_df = pd.DataFrame.from_dict(areas, orient="index").reindex(DESIGN_NAMES)
    return area_df, power_df


############# High Level Operations
def populate_tmp_dir(CLK_LIST):
    if os.path.exists(TMP_DIR):
        try:
            shutil.rmtree(TMP_DIR)
        except PermissionError as e:
            logger.warning("Could not delete TMP directory. Error Message: ")
            logger.warning(f"  {e}")
    try:
        os.makedirs(TMP_DIR)
    except:
        logger.warning("Could not create TMP directory!")
    for DES in DESIGN_NAMES:
        for CLK in CLK_LIST:
            MAPPING = f"clk:{CLK:3.2f}-{CLK:3.2f}-{CLK:3.2f}"
            try:
                os.makedirs(f"{TMP_DIR}/{DES}/{MAPPING}")
            except:
                logger.warning(f"Could not create {DES} subdirectory in TMP")


def synthesis(CLK, DES):
    # Additional Parameters
    MAPPING = f"clk:{CLK:3.2f}-{CLK:3.2f}-{CLK:3.2f}"
    EXPORT_PATH = f"{RESULT_DIR}/{DES}/{MAPPING}"
    REPORT_FILE = f"{EXPORT_PATH}/report_syn.rpt"

    os.chdir(f"{TMP_DIR}/{DES}/{MAPPING}")
    # Create synthesis setup script (tcl)
    generate_syn_setup_script(
        export=EXPORT_PATH, des=DES, report=REPORT_FILE, clk_8=CLK, clk_4=CLK, clk_2=CLK
    )
    # BOOKMARK: Run genus with the synthesis script
    # If already synthesized and exported .v and .sdf file, don't synthesize again!
    if not os.path.exists(f"{EXPORT_PATH}/post.v"):
        logger.info(
            f"\nSTARTING SYNTHESIS OF DESIGN: ({DES}) AT CLOCK PERIODS: {MAPPING}"
        )
        os.system(
            f"genus -legacy_ui -batch -f ./syn_setup.tcl -f {SYN_FILE_L4} >> syn.log"
        )
        try:
            os.makedirs(f"{EXPORT_PATH}/no_backup", exist_ok=True)
            shutil.move(f"syn.log", f"{EXPORT_PATH}/no_backup/syn.log")
        except Exception as e:
            logger.warning(f"  {e}")
        logger.info(
            f"\nFINISHED SYNTHESIS OF DESIGN: ({DES}) AT CLOCK PERIODS: {MAPPING}"
        )
    else:
        logger.info(f"Design ({DES}/{CLK}) already exists! Skipping synthesis")


def power_simulation(prec_tuple, DES, rst=RST, rep=REP, overwrite_vcd=False):
    # Additional Parameters
    PRECISION, CLK = prec_tuple
    MAPPING = f"clk:{CLK:3.2f}-{CLK:3.2f}-{CLK:3.2f}"
    EXPORT_PATH = f"{RESULT_DIR}/{DES}/{MAPPING}"
    REPORT_FILE = f"{EXPORT_PATH}/report_power_{PRECISION}.rpt"
    os.chdir(f"{TMP_DIR}/{DES}/{MAPPING}")

    if os.path.exists(REPORT_FILE) and overwrite_vcd == False:
        logger.info(
            f"{DES}/{CLK} - Report file already exists for {PRECISION}, skipping power simulations!"
        )
    else:
        logger.info(f"{DES}/{CLK} - PRECISION: {PRECISION}, CLOCK PERIOD: {CLK}")
        # Create PB setup script
        logger.info(f"  {DES}/{CLK} - {PRECISION}: Generating VCD")
        generate_PB_setup_script(
            export=EXPORT_PATH, des=DES, prec=PRECISION, clk=CLK, rep=rep, rst=rst
        )
        # BOOKMARK: Run questa and generate VCD files, then correct VCD file by removing pb_L2 and genblk1 scope
        os.system(
            f"vsim -batch -do PB_setup_{PRECISION}_{DES}.tcl -do {SIM_PB_L4} >> vsim_PB_{PRECISION}.log"
        )
        # TB signals are not dumped into VCD, which results in some empty lines in the VCD
        # The line numbers are always (10 -> 15). We use sed to delete these lines
        # If we don't delete these lines, you'll get incorrect power values
        os.system(f"sed -e '10,15d' -i dump_{PRECISION}_clk{CLK:3.2f}_{DES}.vcd")
        # See if there are errors in the simulation
        with open(f"vsim_PB_{PRECISION}.log", "r") as f:
            assert_error = re.search(r"Errors: [1-9][0-9]*", f.readlines()[-1])
        if assert_error:
            logger.warning(f"  {DES}/{CLK} - {PRECISION}: Assertion Error!")

        # Create power setup script
        if os.path.exists(f"./dump_{PRECISION}_clk{CLK:3.2f}_{DES}.vcd"):
            logger.info(f"  {DES}/{CLK} - {PRECISION}: Power Simulation")
            generate_power_setup_script(
                export=EXPORT_PATH, prec=PRECISION, clk=CLK, des=DES, report=REPORT_FILE
            )
            # BOOKMARK: Run genus to extract power readings
            os.system(
                f"genus -legacy_ui -batch -f power_{PRECISION}_{DES}.tcl >> genus_PB_{PRECISION}.log"
            )
            # Move VCD and Power Extraction script to export path in case further analysis is required
            logger.info(f"  {DES}/{CLK} - {PRECISION}: Backing up tcl and log files")
            try:
                os.makedirs(f"{EXPORT_PATH}/no_backup", exist_ok=True)
                shutil.move(
                    f"power_{PRECISION}_{DES}.tcl",
                    f"{EXPORT_PATH}/no_backup/power_{PRECISION}.tcl",
                )
                shutil.move(
                    f"vsim_PB_{PRECISION}.log",
                    f"{EXPORT_PATH}/no_backup/vsim_PB_{PRECISION}.log",
                )
                shutil.move(
                    f"genus_PB_{PRECISION}.log",
                    f"{EXPORT_PATH}/no_backup/genus_PB_{PRECISION}.log",
                )
                logger.info(f"  {DES} - {PRECISION}: Attempting to remove VCD file")
                os.remove(f"dump_{PRECISION}_clk{CLK:3.2f}_{DES}.vcd")
                logger.info(
                    f"  {DES}/{CLK} - {PRECISION}: VCD file deleted successfully!"
                )

            except Exception as e:
                logger.warning(f"  {e}")
        else:
            logger.warning(f"  {DES}/{CLK} - {PRECISION}: Can't find VCD file!")


def generate_breakdown_df(clk_8b, prec_list, dvafs=False):
    MAPPING = f"clk:{clk_8b:3.2f}-{clk_8b:3.2f}-{clk_8b:3.2f}"

    ############ Power and Area Breakdown ############
    BREAKDOWN_DIR = f"{RESULT_DIR}/breakdown/{clk_8b}/{'SWU' if dvafs else 'FU'}/"
    # Create breakdown directory for area and power extraction
    if not os.path.exists(BREAKDOWN_DIR):
        os.makedirs(BREAKDOWN_DIR)
        logger.info(
            f"Breakdown directory does not exist - creating dir in {BREAKDOWN_DIR}"
        )

    # Get area and power dataframes
    logger.info(f"Reading reports and creating dataframes for {MAPPING}")
    area_df, power_df = get_extracted_dataframes(MAPPING, prec_list)

    logger.info("Exporting to CSV")
    # Export CSV files
    area_df.to_csv(f"{BREAKDOWN_DIR}/area.csv")
    power_df.round(5).to_csv(f"{BREAKDOWN_DIR}/power.csv")


def cleanup(DIR):
    # Cleanup - Remove TMP directory
    try:
        shutil.rmtree(DIR)
    except Exception as e:
        logger.warning("Could not delete TMP directory. Error Message: ")
        logger.warning(f"  {e}")
