"""
Levenshtein distance distributions for mismatched Textract cells.

Produces Figs 4 and 5 of the paper (Section 5.1.2):
    Fig 4: histogram of raw Levenshtein distance among mismatched cells
    Fig 5: histogram of normalized Levenshtein similarity

Input:
    data/analysis_intermediates/rows_with_no_equality.csv
    (produced by postprocessing/combine.ipynb)

Outputs:
    figures/fig04_levenshtein_distribution.png
    figures/fig05_levenshtein_normalized.png

Usage (from repo root):
    python analysis/plot_levenshtein.py
"""

from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


REPO_ROOT  = Path(__file__).resolve().parent.parent
INPUT_CSV  = REPO_ROOT / "data" / "analysis_intermediates" / "rows_with_no_equality.csv"
FIG_DIR    = REPO_ROOT / "figures"


def plot_levenshtein_distance(df, output_path):
    """Fig 4: histogram of raw Levenshtein distance."""
    vals = pd.to_numeric(df["Lev_Dist"], errors="coerce").dropna()
    plt.figure()
    plt.hist(vals, bins=20)
    plt.title("Distribution of Levenshtein Distance")
    plt.xlabel("Levenshtein Distance")
    plt.ylabel("Frequency")
    plt.xticks(np.arange(1, 25, 1))
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()


def plot_levenshtein_similarity(df, output_path):
    """Fig 5: histogram of normalized Levenshtein similarity."""
    vals = pd.to_numeric(df["Lev_Sim"], errors="coerce").dropna()
    plt.figure()
    plt.hist(vals, bins=8)
    plt.title("Distribution of Normalized Levenshtein Similarity")
    plt.xlabel("Levenshtein Distance Normalized")
    plt.ylabel("Frequency")
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()


def main():
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    df = pd.read_csv(INPUT_CSV)
    plot_levenshtein_distance(df,   FIG_DIR / "fig04_levenshtein_distribution.png")
    plot_levenshtein_similarity(df, FIG_DIR / "fig05_levenshtein_normalized.png")
    print(f"Wrote figures to {FIG_DIR}/")


if __name__ == "__main__":
    main()
