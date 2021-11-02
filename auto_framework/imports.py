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

#-----------------------------------------------------
# Author:    Ehab Ibrahim
# Function:  Imports and logger setup for Auto Framework
#-----------------------------------------------------

import os 
import shutil
import re
import sys
import time
import pdb
from datetime import timedelta
import logging
from itertools import product
import multiprocessing as mp
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

plt.rcParams.update({'font.size': 12})

# Setting up the logger
log_file = time.strftime("%d-%m_%H:%M:%S", time.localtime()) + "-auto_L4.log"
logger = logging.getLogger('auto_L4')
logger.setLevel(level=logging.DEBUG)
# fh = logging.FileHandler(filename=log_file, encoding='utf-8')
# fh.setFormatter(logging.Formatter('%(asctime)s: %(levelname)-8s: %(message)s', datefmt='%d/%m %H:%M:%S'))
console = logging.StreamHandler()
console.setLevel(logging.INFO)
console.setFormatter(logging.Formatter('%(levelname)-8s: %(message)s'))
# logger.addHandler(fh)
logger.addHandler(console)