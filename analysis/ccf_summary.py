"""
Cross-correlation summary metrics for Section 5.2.1 of the paper.

Replaces the unstable relative-difference column in the per-lag CCF tables
with a small set of stable summary statistics, computed once here and
consumed directly by both the main-text summary table and the Methods text.

Sign convention (fixed throughout): difference = Textract - Manual.
analysis/cross_correlation.R's "Difference" column also uses this
convention directly. This script still recomputes Manual/Textract from
the raw columns and does not rely on the sign of the pre-existing
"Difference" column, but the consistency check below expects them to
agree in sign as well as magnitude.

Inputs (already on disk, produced by analysis/cross_correlation.R):
    data/analysis_intermediates/table1_measles_chickenpox_ccf_diff.csv   (processed, no manual correction)
    data/analysis_intermediates/table2_measles_meningitis_ccf_diff.csv  (manually corrected)
    data/analysis_intermediates/table3_chickenpox_mumps_ccf_diff.csv    (manually corrected)

Outputs:
    data/analysis_intermediates/ccf_summary.csv
        One row per disease pair: max abs diff, lag at max, RMS diff,
        mean abs diff, peak lag M/T, delta peak lag, peak corr M/T,
        delta peak corr.
    data/analysis_intermediates/ccf_per_lag_si.csv
        Lag, Manual, Textract, Difference (Textract - Manual), one block
        per disease pair, 4 dp, no relative-difference column. Feeds the
        Supporting Information tables S1-S3.

Consistency check: before computing anything, this script re-derives
Manual/Textract from the existing CSVs and asserts they match to 4 dp
(they are read directly from the same files, so this is a hygiene check
against future edits to those files, not an independent re-extraction).

Usage (from repo root):
    python analysis/ccf_summary.py
"""

import math
from pathlib import Path

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parent.parent
INT_DIR = REPO_ROOT / "data" / "analysis_intermediates"

PAIRS = [
    {
        "name": "Measles vs Chickenpox",
        "file": INT_DIR / "table1_measles_chickenpox_ccf_diff.csv",
        "data_version": "processed, no manual correction",
    },
    {
        "name": "Measles vs Meningitis",
        "file": INT_DIR / "table2_measles_meningitis_ccf_diff.csv",
        "data_version": "manually corrected",
    },
    {
        "name": "Chickenpox vs Mumps",
        "file": INT_DIR / "table3_chickenpox_mumps_ccf_diff.csv",
        "data_version": "manually corrected",
    },
]


def peak_lag_with_tiebreak(lags, values):
    """argmax with the tie rule: smaller |k|, then negative lag."""
    max_val = max(values)
    tied = [lag for lag, v in zip(lags, values) if v == max_val]
    if len(tied) == 1:
        return tied[0], False
    tied.sort(key=lambda k: (abs(k), 0 if k < 0 else 1))
    return tied[0], True


def summarize_pair(pair):
    df = pd.read_csv(pair["file"])
    df = df.sort_values("Lag").reset_index(drop=True)

    lags = df["Lag"].tolist()
    manual = df["Manual"].tolist()
    textract = df["Textract"].tolist()
    n = len(lags)
    assert n == 25, f"{pair['name']}: expected 25 lags, got {n}"

    # Consistency check against the pre-existing Difference column.
    # Both are now Textract - Manual (see module docstring).
    existing_diff = df["Difference"].tolist()
    for m, t, d in zip(manual, textract, existing_diff):
        assert abs((t - m) - d) < 1e-4, (
            f"{pair['name']}: recomputed Textract-Manual does not match "
            f"existing Difference column to 4dp -- stop, this is a separate "
            f"problem."
        )

    diff_tm = [t - m for m, t in zip(manual, textract)]  # Textract - Manual
    abs_diff = [abs(d) for d in diff_tm]

    max_abs_diff = max(abs_diff)
    lag_at_max, tie_at_max = peak_lag_with_tiebreak(lags, abs_diff)

    rms_diff = math.sqrt(sum(d * d for d in diff_tm) / n)
    mean_abs_diff = sum(abs_diff) / n

    peak_lag_m, tie_m = peak_lag_with_tiebreak(lags, manual)
    peak_lag_t, tie_t = peak_lag_with_tiebreak(lags, textract)
    peak_corr_m = max(manual)
    peak_corr_t = max(textract)

    return {
        "Disease pair": pair["name"],
        "Data version": pair["data_version"],
        "Max abs diff": round(max_abs_diff, 4),
        "Lag at max": lag_at_max,
        "Tie at max abs diff": tie_at_max,
        "RMS diff": round(rms_diff, 4),
        "Mean abs diff": round(mean_abs_diff, 4),
        "Peak lag M": peak_lag_m,
        "Peak lag T": peak_lag_t,
        "Tie peak lag M": tie_m,
        "Tie peak lag T": tie_t,
        "Delta peak lag": peak_lag_t - peak_lag_m,
        "Peak corr M": round(peak_corr_m, 4),
        "Peak corr T": round(peak_corr_t, 4),
        "Delta peak corr": round(peak_corr_t - peak_corr_m, 4),
    }, df


def build_si_table(pair, df):
    out = df[["Lag", "Manual", "Textract"]].copy()
    out["Difference"] = (out["Textract"] - out["Manual"]).round(4)
    out["Manual"] = out["Manual"].round(4)
    out["Textract"] = out["Textract"].round(4)
    out.insert(0, "Disease pair", pair["name"])
    out.insert(1, "Data version", pair["data_version"])
    return out


def main():
    summary_rows = []
    si_blocks = []
    any_tie = False

    for pair in PAIRS:
        summary, df = summarize_pair(pair)
        any_tie = any_tie or summary["Tie at max abs diff"] or summary["Tie peak lag M"] or summary["Tie peak lag T"]
        summary_rows.append(summary)
        si_blocks.append(build_si_table(pair, df))

    summary_df = pd.DataFrame(summary_rows)
    si_df = pd.concat(si_blocks, ignore_index=True)

    summary_path = INT_DIR / "ccf_summary.csv"
    si_path = INT_DIR / "ccf_per_lag_si.csv"
    summary_df.to_csv(summary_path, index=False)
    si_df.to_csv(si_path, index=False)

    print(f"Wrote {summary_path}")
    print(summary_df.to_string(index=False))
    print(f"\nWrote {si_path} ({len(si_df)} rows)")
    print(f"\nAny lag ties encountered (max-abs-diff or peak-lag): {any_tie}")


if __name__ == "__main__":
    main()
