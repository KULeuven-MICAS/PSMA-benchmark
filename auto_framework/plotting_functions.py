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
# Function: Helper functions to produce the Heatmaps and
#           Scatter plots, as well as compute the utilization
#           for non-ideal workloads
# -----------------------------------------------------

from imports import *
from math import ceil
import itertools, pylab
import matplotlib.ticker as mticker

sns.set_theme(context="talk", palette="bright", style="whitegrid")

DESIGN_NAMES = [
    "BG_L2_L4_00_L3_00_L2_00_DVAFS_0",
    "BG_L2_L4_00_L3_00_L2_10_DVAFS_0",
    "BG_L2_L4_00_L3_00_L2_11_DVAFS_0",
    "BG_L2_L4_00_L3_10_L2_00_DVAFS_0",
    "BG_L2_L4_00_L3_10_L2_10_DVAFS_0",
    "BG_L2_L4_00_L3_10_L2_11_DVAFS_0",
    "BG_L2_L4_00_L3_11_L2_00_DVAFS_0",
    "BG_L2_L4_00_L3_11_L2_10_DVAFS_0",
    "BG_L2_L4_00_L3_11_L2_11_DVAFS_0",
    "BG_L2_L4_10_L3_00_L2_00_DVAFS_0",
    "BG_L2_L4_10_L3_00_L2_10_DVAFS_0",
    "BG_L2_L4_10_L3_00_L2_11_DVAFS_0",
    "BG_L2_L4_10_L3_10_L2_00_DVAFS_0",
    "BG_L2_L4_10_L3_10_L2_10_DVAFS_0",
    "BG_L2_L4_10_L3_10_L2_11_DVAFS_0",
    "BG_L2_L4_10_L3_11_L2_00_DVAFS_0",
    "BG_L2_L4_10_L3_11_L2_10_DVAFS_0",
    "BG_L2_L4_10_L3_11_L2_11_DVAFS_0",
    "BG_L2_L4_11_L3_00_L2_00_DVAFS_0",
    "BG_L2_L4_11_L3_00_L2_10_DVAFS_0",
    "BG_L2_L4_11_L3_00_L2_11_DVAFS_0",
    "BG_L2_L4_11_L3_10_L2_00_DVAFS_0",
    "BG_L2_L4_11_L3_10_L2_10_DVAFS_0",
    "BG_L2_L4_11_L3_10_L2_11_DVAFS_0",
    "BG_L2_L4_11_L3_11_L2_00_DVAFS_0",
    "BG_L2_L4_11_L3_11_L2_10_DVAFS_0",
    "BG_L2_L4_11_L3_11_L2_11_DVAFS_0",
    "BG_L3_L4_00_L3_00_L2_10_DVAFS_0",
    "BG_L3_L4_00_L3_00_L2_11_DVAFS_0",
    "BG_L3_L4_00_L3_10_L2_10_DVAFS_0",
    "BG_L3_L4_00_L3_10_L2_11_DVAFS_0",
    "BG_L3_L4_00_L3_11_L2_10_DVAFS_0",
    "BG_L3_L4_00_L3_11_L2_11_DVAFS_0",
    "BG_L3_L4_10_L3_00_L2_10_DVAFS_0",
    "BG_L3_L4_10_L3_00_L2_11_DVAFS_0",
    "BG_L3_L4_10_L3_10_L2_10_DVAFS_0",
    "BG_L3_L4_10_L3_10_L2_11_DVAFS_0",
    "BG_L3_L4_10_L3_11_L2_10_DVAFS_0",
    "BG_L3_L4_10_L3_11_L2_11_DVAFS_0",
    "BG_L3_L4_11_L3_00_L2_10_DVAFS_0",
    "BG_L3_L4_11_L3_00_L2_11_DVAFS_0",
    "BG_L3_L4_11_L3_10_L2_10_DVAFS_0",
    "BG_L3_L4_11_L3_10_L2_11_DVAFS_0",
    "BG_L3_L4_11_L3_11_L2_10_DVAFS_0",
    "BG_L3_L4_11_L3_11_L2_11_DVAFS_0",
    "BG_BS_L4_00_L3_00_L2_11_DVAFS_0",
    "BG_BS_L4_00_L3_10_L2_11_DVAFS_0",
    "BG_BS_L4_00_L3_11_L2_11_DVAFS_0",
    "BG_BS_L4_10_L3_00_L2_11_DVAFS_0",
    "BG_BS_L4_10_L3_10_L2_11_DVAFS_0",
    "BG_BS_L4_10_L3_11_L2_11_DVAFS_0",
    "BG_BS_L4_11_L3_00_L2_11_DVAFS_0",
    "BG_BS_L4_11_L3_10_L2_11_DVAFS_0",
    "BG_BS_L4_11_L3_11_L2_11_DVAFS_0",
]

# Utilization Functions
def loop_unrolls(idx, in_loops, w_loops, out_loops):
    prec, design = idx.name[0], idx.name[1]
    c = re.search("BG_(\w\w)_L4_(\w\w)_L3_(\w\w)_L2_(\w\w)_DVAFS_(\w)", design)
    in_unroll = w_unroll = out_unroll = 1
    BG, L4, L3, L2, DVAFS = c.group(1), c.group(2), c.group(3), c.group(4), c.group(5)
    if L4 == "00":
        in_unroll *= 4
        w_unroll *= 4
    elif L4 == "10":
        in_unroll *= 4
        out_unroll *= 4
    else:
        out_unroll *= 16
    if BG == "L3":
        if L3 == "00":
            if prec == "8x4":
                in_unroll *= 2
            elif prec == "8x2":
                in_unroll *= 4
            elif prec == "4x4":
                w_unroll *= 2
                in_unroll *= 2
            elif prec == "2x2":
                w_unroll *= 4
                in_unroll *= 4
        elif L3 == "10":
            if prec == "8x4":
                out_unroll *= 2
            elif prec == "8x2":
                out_unroll *= 4
            elif prec == "4x4":
                out_unroll *= 2
                in_unroll *= 2
            elif prec == "2x2":
                out_unroll *= 4
                in_unroll *= 4
        else:
            if prec == "8x4":
                out_unroll *= 2
            elif prec == "8x2":
                out_unroll *= 4
            elif prec == "4x4":
                out_unroll *= 4
            elif prec == "2x2":
                out_unroll *= 16
        if L2 == "00":
            in_unroll *= 4
            w_unroll *= 4
        elif L2 == "10":
            in_unroll *= 4
            out_unroll *= 4
        else:
            out_unroll *= 16
    elif BG == "L2":
        if L2 == "00":
            if prec == "8x4":
                in_unroll *= 2
            elif prec == "8x2":
                in_unroll *= 4
            elif prec == "4x4":
                w_unroll *= 2
                in_unroll *= 2
            elif prec == "2x2":
                w_unroll *= 4
                in_unroll *= 4
        elif L2 == "10":
            if prec == "8x4":
                out_unroll *= 2
            elif prec == "8x2":
                out_unroll *= 4
            elif prec == "4x4":
                out_unroll *= 2
                in_unroll *= 2
            elif prec == "2x2":
                out_unroll *= 4
                in_unroll *= 4
        else:
            if prec == "8x4":
                out_unroll *= 2
            elif prec == "8x2":
                out_unroll *= 4
            elif prec == "4x4":
                out_unroll *= 4
            elif prec == "2x2":
                out_unroll *= 16
        if L3 == "00":
            in_unroll *= 4
            w_unroll *= 4
        elif L3 == "10":
            in_unroll *= 4
            out_unroll *= 4
        else:
            out_unroll *= 16
    else:
        if L3 == "00":
            in_unroll *= 4
            w_unroll *= 4
        elif L3 == "10":
            in_unroll *= 4
            out_unroll *= 4
        else:
            out_unroll *= 16
        if L2 == "00":
            in_unroll *= 4
            w_unroll *= 4
        elif L2 == "10":
            in_unroll *= 4
            out_unroll *= 4
        else:
            out_unroll *= 16
    in_util = utilization(loops=in_loops, dims=in_unroll)
    w_util = utilization(loops=w_loops, dims=w_unroll)
    out_util = utilization(loops=out_loops, dims=out_unroll)
    return in_util * w_util * out_util


def utilization(loops, dims):
    if dims < 4:
        return 1.0
    else:
        return (loops / dims) / ceil(loops / dims)


def avg_utilization(loop_dict):
    in_loops = loop_dict["K"]
    w_loops = loop_dict["B"] * loop_dict["OY"] * loop_dict["OX"]
    out_loops = loop_dict["C"] * loop_dict["FY"] * loop_dict["FX"]
    prec_list = ["8x8", "8x4", "8x2", "4x4", "2x2"]
    idx = pd.MultiIndex.from_product(
        [prec_list, DESIGN_NAMES], names=["prec", "design"]
    )
    df_util = pd.DataFrame("0", index=idx, columns=["Utilization"])
    df_util["Utilization"] = df_util.apply(
        loop_unrolls, axis=1, args=(in_loops, w_loops, out_loops)
    )
    return df_util


def square_util(loop_dict):
    df_util = avg_utilization(loop_dict)
    prec_list = ["8x8", "8x4", "8x2", "4x4", "2x2"]
    columns = [
        "BG: L2 / L2:IS",
        "BG: L2 / L2:HS",
        "BG: L2 / L2: OS",
        "BG: L3 / L2: HS",
        "BG: L3 / L2: OS",
        "BG: BS / L2: OS",
    ]
    rows = [
        "L4: IS / L3: IS",
        "L4: IS / L3: HS",
        "L4: IS / L3: OS",
        "L4: HS / L3: IS",
        "L4: HS / L3: HS",
        "L4: HS / L3: OS",
        "L4: OS / L3: IS",
        "L4: OS / L3: HS",
        "L4: OS / L3: OS",
    ]
    idx = pd.MultiIndex.from_product([prec_list, rows], names=["prec", "L4/L3"])
    df_sq = pd.DataFrame("0", index=idx, columns=columns)
    df_sq["BG: L2 / L2:IS"] = df_util.filter(regex="BG_L2_.+_L2_00", axis=0)[
        "Utilization"
    ].tolist()
    df_sq["BG: L2 / L2: OS"] = df_util.filter(regex="BG_L2_.+_L2_11", axis=0)[
        "Utilization"
    ].tolist()
    df_sq["BG: L2 / L2:HS"] = df_util.filter(regex="BG_L2_.+_L2_10", axis=0)[
        "Utilization"
    ].tolist()
    df_sq["BG: L3 / L2: HS"] = df_util.filter(regex="BG_L3_.+_L2_10", axis=0)[
        "Utilization"
    ].tolist()
    df_sq["BG: L3 / L2: OS"] = df_util.filter(regex="BG_L3_.+_L2_11", axis=0)[
        "Utilization"
    ].tolist()
    df_sq["BG: BS / L2: OS"] = df_util.filter(regex="BG_BS_.+_L2_11", axis=0)[
        "Utilization"
    ].tolist()
    return df_sq


# Heatmap Functions
def rnm(s, swu="0"):
    if s == "00" and swu == "0":
        return "IS"
    elif s == "00" and swu == "1":
        return "NO"
    elif s == "11":
        return "OS"
    else:
        return "HS"


def flip(items, ncol):
    # Used to fill legend row first instead of column first
    return itertools.chain(*[items[i::ncol] for i in range(ncol)])


def SWPBGL2(idx):
    c = re.search("BG_(\w\w)_L4_(\w\w)_L3_(\w\w)_L2_(\w\w)_DVAFS_(\w)", idx)
    return f"{'FU' if c.group(5) == '0' else 'SWU'}\nBG: {c.group(1)}\nL2: {rnm(c.group(4), c.group(5))}"


def SWPBGL2_noline(idx):
    c = re.search("BG_(\w\w)_L4_(\w\w)_L3_(\w\w)_L2_(\w\w)_DVAFS_(\w)", idx)
    return f"{'FU' if c.group(5) == '0' else 'SWU'} / BG: {c.group(1)} / L2: {rnm(c.group(4), c.group(5))}"


def BGL2(idx):
    c = re.search("BG_(\w\w)_L4_(\w\w)_L3_(\w\w)_L2_(\w\w)_DVAFS_(\w)", idx)
    return f"BG: {c.group(1)} / L2: {rnm(c.group(4))}"


def L4L3(idx):
    c = re.search("BG_(\w\w)_L4_(\w\w)_L3_(\w\w)_L2_(\w\w)_DVAFS_(\w)", idx)
    return f"L4: {rnm(c.group(2))} / L3: {rnm(c.group(3))}"


def SWP(idx):
    c = re.search("BG_(\w\w)_L4_(\w\w)_L3_(\w\w)_L2_(\w\w)_DVAFS_(\w)", idx)
    return f"{'FU' if c.group(5)=='0' else 'SWU'}"


def scatter_extract(
    df_scatter,
    plt_all=False,
    ext="png",
    export="./",
    name="all",
    legend="auto",
    palette=None,
):
    g = sns.relplot(
        data=df_scatter.reset_index(),
        x="Area",
        y="Energy/Op",
        col="prec",
        style="L4 / L3 Modes",
        # size="SWP",
        hue="Config / BG / L2",
        col_wrap=2,
        aspect=1,
        kind="scatter",
        # s is responsible for the size of points
        s=250,
        alpha=0.6,
        palette=palette,
        facet_kws={"sharey": False, "sharex": False},
        legend=legend,
    )
    g.set(xlim=[0.095, 0.5])
    g.set(yscale="log", xscale="log")
    g.set_titles("{col_name}", fontweight="bold", size=20)
    for idx, axis in enumerate(g.axes):
        axis.yaxis.set_minor_formatter(mticker.ScalarFormatter())
        axis.yaxis.set_major_formatter(mticker.ScalarFormatter())
        if idx in [0, 2]:
            axis.set_ylabel("Energy/Op ($fJ$)")
        if idx in [2, 3]:
            axis.set_xlabel("Area ($mm^2$)")
            axis.xaxis.set_major_formatter(mticker.FormatStrFormatter('%.1f'))
            axis.xaxis.set_minor_formatter(mticker.FormatStrFormatter('%.1f'))
        else:
            axis.xaxis.set_major_formatter(mticker.NullFormatter())
            axis.xaxis.set_minor_formatter(mticker.NullFormatter())
        axis.grid(b=True, which="minor", linewidth=0.5)
    if g.legend is not None:
        # Increase size of legend's shapes and colors
        for lh in g._legend.legendHandles:
            lh._sizes = [200]
        # Make legend titles BOLD. Unfortunately, in seaborn, they're set as text and not titles
        # So, we use get_texts(), and the indices (0, 7) are hard-coded, and subject to change
        plt.setp(g.legend.get_texts()[0], fontweight="bold")  # for legend text
        plt.setp(g.legend.get_texts()[9], fontweight="bold")  # for legend text
        # Move the legend a little bit to the right
        g.legend.set_bbox_to_anchor((1.01, 0.5))
    plt.savefig(
        f"{export}/relplot_{name}.{ext}", dpi=300, bbox_inches="tight",
    )
    plt.clf()
    if plt_all:
        prec_list = ["8b x 8b", "8b x 2b", "4b x 4b", "2b x 2b"]
        for prec in prec_list:
            g = sns.scatterplot(
                data=df_scatter.loc[prec],
                x="Area",
                y="Energy/Op",
                s=150,
                style="BG Unrolling / L2 Mode",
                hue="L4 / L3 Modes",
            )
            plt.legend(bbox_to_anchor=(1.05, 1), loc=2, borderaxespad=0.0)
            g.set(xlabel="Area (x10^3)", ylabel="Energy/Op (fJ)")
            plt.savefig(
                f"{export}/scatter_{prec}.{ext}", dpi=300, bbox_inches="tight",
            )
            plt.clf()


def draw_heatmap(*args, **kwargs):
    data = kwargs.pop("data")
    idx_name = kwargs.pop("idx")
    d = data.set_index("L4/L3").drop(idx_name, axis=1)
    sns.heatmap(d, **kwargs)


def energy_extract(clk, DVAFS=False):
    DIR = f"../results/breakdown/{clk}/{'SWU' if DVAFS else 'FU'}"
    df = pd.read_csv(f"{DIR}/power.csv", index_col=[0, 1])
    clock = float(clk)
    # Clock is in nano seconds, Power is in nano watts by default in Genus 19.1
    # Operation is defined as 1 multiplication or 1 addition
    # At 8x8-bits precision, 256 multiplications and 256 additions are performed
    # To compute Energy in (fJ) -> Clk (nS) * Power (nW) * (10^3) / #operations 
    df.loc["8x8"] = df.loc["8x8"].mul(clock * (10 ** 3) / 512).values
    if not DVAFS:
        df.loc["8x4"] = df.loc["8x4"].mul(clock * (10 ** 3) / 1024).values
        df.loc["8x2"] = df.loc["8x2"].mul(clock * (10 ** 3) / 2048).values
        df.loc["4x4"] = df.loc["4x4"].mul(clock * (10 ** 3) / 2048).values
        df.loc["2x2"] = df.loc["2x2"].mul(clock * (10 ** 3) / 8192).values
    else:
        df.loc["4x4"] = df.loc["4x4"].mul(clock * (10 ** 3) / 1024).values
        df.loc["2x2"] = df.loc["2x2"].mul(clock * (10 ** 3) / 2048).values
    df.rename(
        index={
            "BITFUSION": "BG_L2_L4_00_L3_11_L2_11_DVAFS_0",
            "BITBLADE": "BG_L3_L4_00_L3_11_L2_11_DVAFS_0",
            "LOOM": "BG_BS_L4_00_L3_00_L2_11_DVAFS_0",
        },
        inplace=True,
    )
    if DVAFS:
        prec_list = ["8x8", "4x4", "2x2"]
        columns = ["SWU / BG: L2 / L2: NO", "SWU / BG: L2 / L2: OS"]
    else:
        prec_list = ["8x8", "8x4", "8x2", "4x4", "2x2"]
        columns = [
            "FU / BG: L2 / L2: IS",
            "FU / BG: L2 / L2: HS",
            "FU / BG: L2 / L2: OS",
            "FU / BG: L3 / L2: HS",
            "FU / BG: L3 / L2: OS",
            "FU / BG: BS / L2: OS",
        ]
    rows = [
        "L4: IS / L3: IS",
        "L4: IS / L3: HS",
        "L4: IS / L3: OS",
        "L4: HS / L3: IS",
        "L4: HS / L3: HS",
        "L4: HS / L3: OS",
        "L4: OS / L3: IS",
        "L4: OS / L3: HS",
        "L4: OS / L3: OS",
    ]
    idx = pd.MultiIndex.from_product([prec_list, rows], names=["prec", "L4/L3"])
    df_sq = pd.DataFrame("0", index=idx, columns=columns)
    if DVAFS:
        df_sq["SWU / BG: L2 / L2: NO"] = df.filter(regex="BG_L2_.+_L2_00", axis=0)[
            "top"
        ].tolist()
        df_sq["SWU / BG: L2 / L2: OS"] = df.filter(regex="BG_L2_.+_L2_11", axis=0)[
            "top"
        ].tolist()
        for prec in ["8x4", "8x2"]:
            for row in rows:
                df_sq.loc[(prec, row), :] = df_sq.mean(axis=0).mean()
    else:
        df_sq["FU / BG: L2 / L2: IS"] = df.filter(regex="BG_L2_.+_L2_00", axis=0)[
            "top"
        ].tolist()
        df_sq["FU / BG: L2 / L2: OS"] = df.filter(regex="BG_L2_.+_L2_11", axis=0)[
            "top"
        ].tolist()
        df_sq["FU / BG: L2 / L2: HS"] = df.filter(regex="BG_L2_.+_L2_10", axis=0)[
            "top"
        ].tolist()
        df_sq["FU / BG: L3 / L2: HS"] = df.filter(regex="BG_L3_.+_L2_10", axis=0)[
            "top"
        ].tolist()
        df_sq["FU / BG: L3 / L2: OS"] = df.filter(regex="BG_L3_.+_L2_11", axis=0)[
            "top"
        ].tolist()
        df_sq["FU / BG: BS / L2: OS"] = df.filter(regex="BG_BS_.+_L2_11", axis=0)[
            "top"
        ].tolist()
    return df_sq


def heatmap_extract(
    df_sq,
    name="all",
    plt_all=False,
    ext="png",
    cmap="rocket",
    DVAFS=False,
    export="./",
    ylabels=True,
):
    file_name = f"heatmap_{name}"
    idx_name = df_sq.index.names[0]
    g = sns.FacetGrid(
        data=df_sq.reset_index(), col=idx_name, col_wrap=2, height=6, aspect=1.3,
    )
    g.map_dataframe(
        draw_heatmap, data=df_sq, cmap=cmap, idx=idx_name, annot=True, fmt=".0f"
    )
    if not ylabels:
        g.set(yticklabels=[])
    g.set_titles("{col_name}", fontweight="bold", size=20)
    plt.savefig(
        f"{export}/{file_name}.{ext}", dpi=300, bbox_inches="tight",
    )
    plt.clf()
    if plt_all:
        if DVAFS:
            prec_list = ["8b x 8b", "4b x 4b", "2b x 2b"]
        else:
            prec_list = ["8b x 8b", "8b x 4b", "8b x 2b", "4b x 4b", "2b x 2b"]
        for prec in prec_list:
            sns.heatmap(df_sq.loc[prec], cmap=cmap, annot=True, fmt=".0f")
            plt.savefig(
                f"{export}/{file_name}_{prec}.{ext}", dpi=300, bbox_inches="tight"
            )
            plt.clf()


def plot_clustered_stacked(
    multiindex_df,
    title="Clustered Stacked Bar Plot",
    save=False,
    export="./",
    ext=".png",
    sep_legend=False,
    figsize=(20, 5),
    **kwargs,
):
    indices = multiindex_df.index.remove_unused_levels().levels[0]
    n_subplots = len(indices)
    fig, axes = plt.subplots(nrows=1, ncols=n_subplots, sharey=True, figsize=figsize)
    graph = dict(zip(indices, axes))
    for key in graph:
        ax = graph[key]
        multiindex_df.xs(key).plot.bar(
            align="center", stacked="True", ax=ax, legend=False, zorder=2, **kwargs
        )
        ax.minorticks_on()
        ax.grid(
            axis="y",
            b=True,
            which="minor",
            color="#666666",
            linestyle="-",
            alpha=0.2,
            zorder=0,
        )
        ax.grid(
            axis="y",
            b=True,
            which="major",
            color="#666666",
            linestyle="-",
            alpha=0.7,
            zorder=0,
        )
        ax.set_xlabel(key, fontsize=30)
        # Disable vertical grid lines
        ax.xaxis.grid(False)
        # Increase ticks fint size
        ax.tick_params(axis="both", which="both", labelsize=30)
        # Disable x axis labels
        ax.set_xticks([])
        # Rotate x axis labels by 45 degrees
        # plt.setp(ax.xaxis.get_majorticklabels(), rotation=45, ha="right")
        for border in ["left", "right"]:
            ax.spines[border].set_edgecolor("black")
    fig.subplots_adjust(wspace=0)
    handles, labels = ax.get_legend_handles_labels()
    if not sep_legend:
        fig.legend(
            handles,
            labels,
            # loc="upper center",
            loc="upper right",
            ncol=1,
            fontsize=30,
            # bbox_to_anchor=(0.5, 1.05),
            bbox_to_anchor=(0.9, 0.88),
            framealpha=1.0,
        )
    else:
        figlegend = pylab.figure()
        figlegend.legend(
            flip(handles, 4),
            flip(labels, 4),
            loc="center",
            ncol=4,
            fontsize=30,
            # bbox_to_anchor=(0.5, 1.05),
        )
    # fig.suptitle(title, fontsize=24)
    if save:
        fig.savefig(f"{export}/{title}.{ext}", bbox_inches="tight", transparent=False)
        if sep_legend:
            figlegend.savefig(
                f"{export}/legend.{ext}", bbox_inches="tight", transparent=False
            )
        plt.close(fig)
