"""
Time-series overlay plots used in Section 5.2 of the paper.

Produces:
    Fig 10  Manual vs Textract: Chickenpox + Measles, 1956-1958
    Fig 12  Manual vs Textract: Measles + Meningitis (Meningitis hardcoded)
    Fig 13  Manual vs Textract: Meningitis only (showing the post-processing effect)
    Fig 15  Manual vs Textract: Chickenpox + Mumps, 1956-1958
    Fig 20  Textract: Chickenpox + Mumps, before hardcoding
    Fig 21  Textract: Measles + Meningitis, before hardcoding

Inputs (under data/timeseries/):
    measles_chickenpox/1956-1958_manual_timeseries_chickenpox_measles.csv
    measles_chickenpox/1956-1958_textract_timeseries_chickenpox_measles.csv
    meningitis_measles/1956-1958_manual_timeseries_meningitis_measles.csv
    meningitis_measles/1956-1958_textract_timeseries_meningitis_measles.csv
    meningitis_measles/1956-1958_textract_hardcoded.csv
    chickenpox_mumps/1956-1958_manual_timeseries_chickenpox_mumps.csv
    chickenpox_mumps/1956-1958_textract_timeseries_chickenpox_mumps.csv
    chickenpox_mumps/1956-1958_textract_timeseries_hardcoded.csv

Outputs (under figures/):
    fig10_chickenpox_measles_overlay.png
    fig12_measles_meningitis_overlay.png
    fig13_meningitis_manual_vs_textract.png
    fig15_chickenpox_mumps_overlay.png
    fig20_textract_chickenpox_mumps_raw.png
    fig21_textract_measles_meningitis_raw.png

Usage (from repo root):
    python analysis/timeseries_plots.py
"""

from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt


REPO_ROOT  = Path(__file__).resolve().parent.parent
TS_DIR     = REPO_ROOT / "data" / "timeseries"
FIG_DIR    = REPO_ROOT / "figures"


def _load(path, time_col="Row"):
    """Load a time-series CSV, drop unnamed columns, coerce numerics, sort by time_col."""
    df = pd.read_csv(path)
    df = df.loc[:, ~df.columns.str.contains("^Unnamed")]
    for col in df.columns:
        if col != time_col:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    df[time_col] = pd.to_numeric(df[time_col], errors="coerce")
    df = df.dropna(subset=[time_col]).sort_values(time_col)
    return df


def plot_two_diseases(csv_path, disease_a, disease_b, title, output_path,
                      color_a="orange", color_b="green", time_col="Row"):
    """Plot two disease time series from a single CSV on one axis."""
    df = _load(csv_path, time_col=time_col)
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.plot(df[time_col], df[disease_a], label=disease_a, color=color_a)
    ax.plot(df[time_col], df[disease_b], label=disease_b, color=color_b)
    ax.set_xlabel("Week Index")
    ax.set_ylabel("Cases")
    ax.set_title(title)
    ax.legend()
    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)


def plot_manual_vs_textract(manual_csv, textract_csv, disease, title, output_path,
                            time_col="Row"):
    """Plot one disease from manual vs textract on one axis."""
    m = _load(manual_csv, time_col=time_col)
    t = _load(textract_csv, time_col=time_col)
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.plot(m[time_col], m[disease], label="Manual",   color="steelblue")
    ax.plot(t[time_col], t[disease], label="Textract", color="orange")
    ax.set_xlabel("Week Index")
    ax.set_ylabel("Cases")
    ax.set_title(title)
    ax.legend()
    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)


def main():
    FIG_DIR.mkdir(parents=True, exist_ok=True)

    mc_dir   = TS_DIR / "measles_chickenpox"
    mn_dir   = TS_DIR / "meningitis_measles"
    cm_dir   = TS_DIR / "chickenpox_mumps"

    # Fig 10: Chickenpox + Measles (manual data; same shape works for textract)
    plot_two_diseases(
        mc_dir / "1956-1958_manual_timeseries_chickenpox_measles.csv",
        disease_a="Chickenpox", disease_b="Measles",
        title="Chickenpox vs Measles, 1956-1958 (Manual)",
        output_path=FIG_DIR / "fig10_chickenpox_measles_overlay.png",
    )

    # Fig 12: Measles + Meningitis (manual)
    plot_two_diseases(
        mn_dir / "1956-1958_manual_timeseries_meningitis_measles.csv",
        disease_a="Measles", disease_b="Meningitis",
        title="Measles vs Meningitis, 1956-1958 (Manual)",
        output_path=FIG_DIR / "fig12_measles_meningitis_overlay.png",
    )

    # Fig 13: Meningitis only - manual vs textract (post-hardcoding)
    plot_manual_vs_textract(
        manual_csv   = mn_dir / "1956-1958_manual_timeseries_meningitis_measles.csv",
        textract_csv = mn_dir / "1956-1958_textract_hardcoded.csv",
        disease      = "Meningitis",
        title        = "Meningitis: Manual vs Textract (hardcoded)",
        output_path  = FIG_DIR / "fig13_meningitis_manual_vs_textract.png",
    )

    # Fig 15: Chickenpox + Mumps (manual)
    plot_two_diseases(
        cm_dir / "1956-1958_manual_timeseries_chickenpox_mumps.csv",
        disease_a="Chickenpox", disease_b="Mumps",
        title="Chickenpox vs Mumps, 1956-1958 (Manual)",
        output_path=FIG_DIR / "fig15_chickenpox_mumps_overlay.png",
    )

    # Fig 20: Textract Chickenpox + Mumps (pre-hardcoding)
    plot_two_diseases(
        cm_dir / "1956-1958_textract_timeseries_chickenpox_mumps.csv",
        disease_a="Chickenpox", disease_b="Mumps",
        title="Chickenpox vs Mumps, 1956-1958 (Textract, raw)",
        output_path=FIG_DIR / "fig20_textract_chickenpox_mumps_raw.png",
    )

    # Fig 21: Textract Measles + Meningitis (pre-hardcoding)
    plot_two_diseases(
        mn_dir / "1956-1958_textract_timeseries_meningitis_measles.csv",
        disease_a="Measles", disease_b="Meningitis",
        title="Measles vs Meningitis, 1956-1958 (Textract, raw)",
        output_path=FIG_DIR / "fig21_textract_measles_meningitis_raw.png",
    )

    print(f"Wrote figures to {FIG_DIR}/")


if __name__ == "__main__":
    main()
