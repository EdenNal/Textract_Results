# Textract Results

Code and data for *"Evaluation of automated table extraction for historical infectious-disease surveillance data"* (Nalian, Walker, & Earn), which assesses Amazon Textract as a tool for digitizing the 1956 Canada Notifiable Disease Dataset (CANDID).

This repository contains everything needed to reproduce the figures and tables in the paper from the PDFs of the source tables.

## Repository layout

```
Textract_Results/
├── data/
│   ├── pdfs/{1956,1957,1958}/           Weekly CANDID tables, scanned PDFs
│   ├── source_xlsx/                     Manually-entered ground truth (Excel)
│   ├── manual/{1956,1957,1958}/         Manual data, one CSV per week
│   ├── textract_raw/{1956,1957,1958}/   Textract output, one CSV per week
│   ├── manual_cleaned/1956/             Manual data after post-processing
│   ├── textract_cleaned/1956/           Textract data after post-processing
│   ├── timeseries/                      Aggregated multi-year series, by disease pair
│   └── analysis_intermediates/          Comparison tables consumed by plot scripts
├── extraction/                          Section 2: PDF -> CSV
├── postprocessing/                      Section 2.2: cleaning + comparison
├── analysis/                            Sections 5.1, 5.2, 5.3: figures and tables
├── figures/                             Generated figures (+ figures_tiff/ for submission-quality TIFFs)
└── agreement.py                         Standalone Wilson-CI agreement script (see Known limitations)
```

## Reproducing the paper

Run the scripts in the order below. Each step's output is the next step's input.

### Prerequisites

```bash
pip install boto3 openpyxl pandas matplotlib nltk jupyter nbconvert
# R packages (run once)
Rscript -e 'install.packages(c("ggplot2", "patchwork", "dplyr", "epigrowthfit"))'
```

For Section 2 (extraction), you also need AWS credentials configured via `aws configure`. Sections 3 and onward can be reproduced from the cached `data/textract_raw/` files without re-running Textract.

### Step 1. Extract tables from PDFs (Section 2.1)

If you want to regenerate the Textract output from scratch (otherwise skip to step 2):

```bash
python extraction/AWS_Python_Table_Extraction.py data/pdfs/1956 data/textract_raw/1956
python extraction/AWS_Python_Table_Extraction.py data/pdfs/1957 data/textract_raw/1957
python extraction/AWS_Python_Table_Extraction.py data/pdfs/1958 data/textract_raw/1958
```

### Step 2. Clean the data (Section 2.2)

The cleaning step strips preamble rows and pads short rows so every row in a weekly file has the same column count. Open `postprocessing/Cleaning_fixed.ipynb` and **Run All**.

Output: `data/textract_cleaned/1956/` and `data/manual_cleaned/1956/` (52 files each).

### Step 3. Compare cleaned data cell-by-cell (Section 5.1)

Open `postprocessing/combine.ipynb` and **Run All**.

Output:
- `data/analysis_intermediates/Levels_of_Accuracy.csv` (one row per cell)
- `data/analysis_intermediates/rows_with_no_equality.csv` (mismatched cells with Levenshtein distance)
- `data/analysis_intermediates/accuracy_summary.csv` (the Section 5.1.1 equality percentages under all three denominators — see below; feeds the paper's Table 1)

### Step 4. Generate the figures

```bash
python analysis/plot_levenshtein.py   # Figs 4, 5
python analysis/row_sum_check.py      # Figs 7, 9
python analysis/timeseries_plots.py   # Figs 10, 12, 13, 15, 20, 21
Rscript analysis/cross_correlation.R  # Figs 11, 14, 16 + Supplementary Tables S1-S3
Rscript analysis/growthrates.R        # Figs 17, 18 + Tables 4, 5
Rscript analysis/boxplots.R           # Fig 22
```

Each script header documents its own inputs/outputs; see the [Figure and table index](#figure-and-table-index) below for the full mapping.

`analysis/cross_correlation.R` merges the manual and Textract series for each disease pair on their shared week identifier and restricts to weeks with complete data on both sides *before* computing either series' cross-correlation, so both are compared over identical calendar weeks. Its per-lag `Difference` column follows the sign convention used throughout the paper: **Textract − Manual**.

### Step 5. Manual correction ("hardcoding") of the Meningitis and Mumps series

Two of the three cross-correlation comparisons (Measles-vs-Meningitis, Chickenpox-vs-Mumps — paper Table 3 rows, Figs 12–16) are **not** computed from the raw output of Step 3/4. They use a manually corrected Textract series instead:

- `data/timeseries/meningitis_measles/1956-1958_textract_hardcoded.csv`
- `data/timeseries/chickenpox_mumps/1956-1958_textract_timeseries_hardcoded.csv`

**This step is not scripted.** These two files were produced by hand: large, isolated spikes in the raw Textract series (visible via `analysis/boxplots.R`'s violin plots, Fig 22) were checked against the source scans and corrected in place. This is described in the paper as §5.3 ("Remarks on Dataset Specific Coding") and disclosed as a leakage/generalizability limitation in §6.2. If you need to regenerate these files (e.g. after re-running Textract from scratch), you must repeat that manual review — there is no automated equivalent in this repository. The Measles-vs-Chickenpox comparison does **not** go through this step, so it reflects the pipeline's automated output only.

### Step 6. Cross-correlation summary statistics

```bash
python analysis/ccf_summary.py   # CCF summary table + per-lag Supporting Information tables
```

Reads the three per-lag CCF CSVs from Step 4 and computes, per disease pair, stable summary statistics: max absolute difference, RMS difference, peak lag and peak correlation for each source, and the change between them. Sign convention throughout: **difference = Textract − Manual**. Outputs:

- `data/analysis_intermediates/ccf_summary.csv` — one row per disease pair; feeds the paper's Table 3
- `data/analysis_intermediates/ccf_per_lag_si.csv` — per-lag values (Lag, Manual, Textract, Difference); feeds Supporting Information Tables S1–S3

### Step 7. Growth-rate and doubling-time reporting

```bash
Rscript analysis/growthrates.R   # same script as Step 4; also writes growth_rate_summary.csv
```

Also emits `data/analysis_intermediates/growth_rate_summary.csv` — one row per disease × window × source, with the initial growth rate `r` (per week) and its 95% CI, doubling time `Td` (weeks) and its 95% CI, `n_obs` per fitting window, convergence status, and `Delta_r` / `Delta_Td` (Textract − Manual).

The model's `formula_parameters` are left at their package default (`~1`) for every top-level parameter, including `log(r)`, so `egf()` fits a single growth rate shared across both fitting windows per disease/source, not one rate per window — this is why Table 4/5 report one `r`/`Td` per source rather than two. This is stated explicitly in the paper's Methods (model-specification paragraph) and in the Fig 17/18 captions.

**Not available in this repository:** a multi-data-version growth-rate comparison (raw vs. processed vs. manually corrected) for Measles/Chickenpox. Only the Stage-2 processed Textract series exists for those two diseases — the manual "hardcoding" correction (Step 5) was applied only to Meningitis and Mumps, and there is no separately saved pre-processing ("raw") version of the Measles/Chickenpox series distinct from the processed one. Disclosed as a scope limitation in the paper (§6.2) rather than worked around.

## Figure and table index

| Figure / Table | Script | Source data |
|---|---|---|
| Fig 4 (Levenshtein distance histogram) | `analysis/plot_levenshtein.py` | `rows_with_no_equality.csv` |
| Fig 5 (Normalized Levenshtein) | `analysis/plot_levenshtein.py` | `rows_with_no_equality.csv` |
| Fig 7 (Chickenpox row-sum diffs) | `analysis/row_sum_check.py` | `data/textract_raw/1956/` |
| Fig 9 (Measles row-sum diffs) | `analysis/row_sum_check.py` | `data/textract_raw/1956/` |
| Fig 10 (Measles vs Chickenpox time series) | `analysis/timeseries_plots.py` | `data/timeseries/measles_chickenpox/` |
| Fig 11 (Measles vs Chickenpox CCF) | `analysis/cross_correlation.R` | `data/timeseries/measles_chickenpox/` |
| Fig 12 (Measles vs Meningitis time series) | `analysis/timeseries_plots.py` | `data/timeseries/meningitis_measles/` |
| Fig 13 (Meningitis manual vs Textract) | `analysis/timeseries_plots.py` | `data/timeseries/meningitis_measles/` |
| Fig 14 (Measles vs Meningitis CCF) | `analysis/cross_correlation.R` | `data/timeseries/meningitis_measles/` |
| Fig 15 (Chickenpox vs Mumps time series) | `analysis/timeseries_plots.py` | `data/timeseries/chickenpox_mumps/` |
| Fig 16 (Chickenpox vs Mumps CCF) | `analysis/cross_correlation.R` | `data/timeseries/chickenpox_mumps/` |
| Fig 17 (Measles doubling time) | `analysis/growthrates.R` | `data/timeseries/measles_chickenpox/` |
| Fig 18 (Chickenpox doubling time) | `analysis/growthrates.R` | `data/timeseries/chickenpox_mumps/` |
| Fig 20 (Raw Textract Chickenpox+Mumps) | `analysis/timeseries_plots.py` | `data/timeseries/chickenpox_mumps/` |
| Fig 21 (Raw Textract Measles+Meningitis) | `analysis/timeseries_plots.py` | `data/timeseries/meningitis_measles/` |
| Fig 22 (Meningitis boxplots) | `analysis/boxplots.R` | `data/timeseries/meningitis_measles/` |
| Table 1 (accuracy pipeline) | `postprocessing/combine.ipynb` | `data/analysis_intermediates/accuracy_summary.csv` |
| Table 2 (Levenshtein distance) | `postprocessing/combine.ipynb` | `data/analysis_intermediates/rows_with_no_equality.csv` |
| Table 3 (CCF summary across all three disease pairs) | `analysis/ccf_summary.py` | `data/analysis_intermediates/ccf_summary.csv` |
| Table 4 (Measles peak + growth-rate comparison) | `analysis/growthrates.R` | `table4_measles_peak_comparison.csv`, `growth_rate_summary.csv` |
| Table 5 (Chickenpox peak + growth-rate comparison) | `analysis/growthrates.R` | `table5_chickenpox_peak_comparison.csv`, `growth_rate_summary.csv` |
| Supplementary Table S1 (Measles vs Chickenpox per-lag CCF) | `analysis/cross_correlation.R` + `ccf_summary.py` | `table1_measles_chickenpox_ccf_diff.csv`, `ccf_per_lag_si.csv` |
| Supplementary Table S2 (Measles vs Meningitis per-lag CCF) | `analysis/cross_correlation.R` + `ccf_summary.py` | `table2_measles_meningitis_ccf_diff.csv`, `ccf_per_lag_si.csv` |
| Supplementary Table S3 (Chickenpox vs Mumps per-lag CCF) | `analysis/cross_correlation.R` + `ccf_summary.py` | `table3_chickenpox_mumps_ccf_diff.csv`, `ccf_per_lag_si.csv` |

Screenshots used as Figures 1, 2, 3, 6, 8, and 19 are not generated by code; they live under `figures/screenshots/`.

## Note on Section 5.1.1 percentages

The paper reports cell-agreement percentages under three denominators, computed by `postprocessing/combine.ipynb` and exported to `data/analysis_intermediates/accuracy_summary.csv`:

| Equality criterion | All cells (n = 53,872) | Numeric, manual reference (n = 28,255) | Numeric, both sources (n = 26,069) |
|---|---:|---:|---:|
| Strict equality (content + position) | 74.0% | 71.9% | 77.9% |
| + Commas/spaces normalized | 76.8% | 77.3% | 83.8% |
| + Row-shift tolerance (content-only, adjacent column) | 88.5% | **92.9%** | 95.6% |

The **primary numeric-accuracy figure used in the paper** is the "Numeric, manual reference" column: every cell where the manual transcription holds a numeric value, regardless of what Textract read there. It's used in preference to the "Numeric, both sources" column because it doesn't silently exclude cells where Textract failed to extract a number at all. "Numeric, both sources" is reported as a secondary figure for comparability with denominators used elsewhere in the OCR-evaluation literature.

The "All cells" column counts every cell in every 1956 weekly table (53,872 cells total), including dashes (used in the source PDFs to mean *zero cases*) and dots (used to mean *missing data*), which match trivially between Textract and the manual data and tell us nothing about Textract's accuracy.

Of the 53,872 evaluated cells, **6,177 (11.5%)** are true extraction errors under the row-shift-tolerant criterion. See `data/analysis_intermediates/rows_with_no_equality.csv` for their Levenshtein-distance distribution (mean distance 1.84; 38.1% at distance 1, 51.7% at distance 2).

The evaluated overlap (53,872 cells) excludes 7,244 cells present in the full 61,116-cell cleaned Textract bounding grids (52 tables × their row×column extent). This isn't automatically 7,244 additional errors — it can include border/padding rows, repeated header rows, or other structural artefacts of aligning two independently formatted tables; see the Methods for the full disclosure.

## Known limitations of this repository

- **Raw Textract API responses are not preserved.** The exact JSON responses, AWS region/account configuration, and extraction date(s) used to produce the checked-in `textract_raw/` CSVs are not stored here — only the processed CSV outputs of the extraction step. This is disclosed in the paper's Data Availability statement and Limitations section.
- **No archived DOI.** This repository has no tagged releases, so there is no Zenodo (or similar) DOI to cite for a fixed snapshot — the Data Availability statement points to the live GitHub repository instead.
- **`agreement.py` is not wired into the numbered pipeline above.** It's a standalone script at the repo root that recomputes cell agreement directly from `data/textract_raw|cleaned` vs. `data/manual|manual_cleaned` and reports Wilson confidence intervals, for anyone who wants a disagreement-taxonomy audit of the 6,177 mismatched cells beyond what's in the paper. Usage: `python agreement.py <textract_dir> <manual_dir>`.
- **`figures/figures_tiff/`** holds submission-quality TIFF exports of the generated figures, in case a submission system requires figures uploaded as separate files; the main manuscript embeds the PNG/PDF versions directly regardless.

## Acknowledgements

Source data: Canada Notifiable Disease Dataset (Dominion Bureau of Statistics, 1956). Manually-entered transcriptions courtesy of McMaster University's Theoretical Biology group.
