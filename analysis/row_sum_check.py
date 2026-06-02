"""
Row-sum validation of Textract cell contents (Section 5.1.3 of the paper).

For each weekly table, picks a single disease's row and verifies that the
sum of the province "Report Week" cells equals the Canada "Report Week"
total reported in the same row. Discrepancies indicate Textract misread
at least one numeric cell.

Produces Figs 7 (Chickenpox) and 9 (Measles) of the paper.

Usage (from repo root):
    python analysis/row_sum_check.py
    python analysis/row_sum_check.py --disease chickenpox
    python analysis/row_sum_check.py --disease measles

Outputs:
    figures/fig07_chickenpox_row_sums.png
    figures/fig09_measles_row_sums.png
    data/analysis_intermediates/{chickenpox,measles}_tables_check.csv
"""

import argparse
import csv
import os
from pathlib import Path

import matplotlib.pyplot as plt


# --- Layout of the cleaned weekly CSV (after Cleaning_fixed.ipynb)
# Column 0  : row number (1-28) in the source PDF
# Column 1  : disease name
# Column 2  : Canada Report Week total            <-- TARGET
# Columns 8, 11, 14, 17, 20, 23, 26, 29, 32, 35 : province Report Week values  <-- CONTRIBUTORS
#   (one per province: NFLD, PEI, NS, NB, QUE, ONT, MAN, SASK, ALTA, BC)

TARGET_COL = 2
CONTRIB_COLS = list(range(8, 36, 3))   # 8, 11, 14, 17, 20, 23, 26, 29, 32, 35

# Diseases analyzed in the paper. Row index is 0-based row in the cleaned table.
DISEASE_ROWS = {
    "chickenpox": 0,
    "measles":    7,
}

REPO_ROOT = Path(__file__).resolve().parent.parent
# Use the raw Textract output (preserves disease-label columns that the
# cleaning step strips). row_sum_check operates on a single named disease row.
TEXTRACT_DIR        = REPO_ROOT / "data" / "textract_raw" / "1956"
INTERMEDIATES_DIR   = REPO_ROOT / "data" / "analysis_intermediates"
FIGURES_DIR         = REPO_ROOT / "figures"


def to_int_or_none(value):
    """Convert a CSV cell to int. Strips commas. Returns None if not numeric."""
    if value is None:
        return None
    s = value.strip().replace(",", "")
    try:
        return int(s)
    except ValueError:
        return None


def compute_row_sum_diffs(disease, textract_dir=TEXTRACT_DIR):
    """For each weekly file, return (week_number, reported_total, computed_sum, contributors).

    contributors is a list of (col_index, value) for cells included in the sum.
    """
    row_idx = DISEASE_ROWS[disease]
    results = []
    for path in sorted(textract_dir.glob("cdi_ca_1956_wk_prov_dbs_Part*_tables.csv"),
                       key=lambda p: int(p.stem.replace("cdi_ca_1956_wk_prov_dbs_Part", "")
                                                 .replace("_tables", ""))):
        week = int(path.stem.replace("cdi_ca_1956_wk_prov_dbs_Part", "").replace("_tables", ""))
        with path.open(newline="", encoding="utf-8-sig") as f:
            rows = list(csv.reader(f))
        if row_idx >= len(rows):
            continue

        row = rows[row_idx]
        target = to_int_or_none(row[TARGET_COL]) if TARGET_COL < len(row) else None
        contributors = []
        for c in CONTRIB_COLS:
            if c < len(row):
                v = to_int_or_none(row[c])
                if v is not None:
                    contributors.append((c, v))
        computed = sum(v for _, v in contributors)

        results.append({
            "week": week,
            "source_file": path.name,
            "reported_total": target,
            "computed_sum": computed,
            "difference": (target - computed) if target is not None else None,
            "contributors": contributors,
        })
    return results


def write_check_csv(results, output_path):
    with output_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["source_file", "value_at_3", "computed_sum", "difference",
                    "values_used", "matches"])
        for r in results:
            values_used = ";".join(f"{c}:{v}" for c, v in r["contributors"])
            matches = (r["reported_total"] == r["computed_sum"]) if r["reported_total"] is not None else False
            w.writerow([r["source_file"], r["reported_total"], r["computed_sum"],
                        r["difference"] if r["difference"] is not None else "",
                        values_used, matches])


def plot_row_sum_diffs(results, disease, output_path):
    weeks, diffs = [], []
    for r in results:
        if r["difference"] is not None:
            weeks.append(r["week"])
            diffs.append(r["difference"])

    plt.figure()
    plt.scatter(weeks, diffs)
    plt.axhline(0, color="black", linewidth=0.5)
    plt.xlabel("Week of 1956")
    plt.ylabel("Difference (reported total - computed sum)")
    plt.title(f"{disease.capitalize()} row-sum validation, 1956 (Textract)")
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()


def run(disease):
    if disease not in DISEASE_ROWS:
        raise ValueError(f"Unknown disease '{disease}'. Choose from {list(DISEASE_ROWS)}.")
    INTERMEDIATES_DIR.mkdir(parents=True, exist_ok=True)
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)

    results = compute_row_sum_diffs(disease)

    csv_path = INTERMEDIATES_DIR / f"{disease}_tables_check.csv"
    write_check_csv(results, csv_path)
    print(f"Wrote {csv_path}")

    fig_num = {"chickenpox": "07", "measles": "09"}[disease]
    fig_path = FIGURES_DIR / f"fig{fig_num}_{disease}_row_sums.png"
    plot_row_sum_diffs(results, disease, fig_path)
    print(f"Wrote {fig_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument("--disease", choices=list(DISEASE_ROWS) + ["all"], default="all",
                        help="Which disease to process (default: all).")
    args = parser.parse_args()

    diseases = list(DISEASE_ROWS) if args.disease == "all" else [args.disease]
    for d in diseases:
        run(d)
