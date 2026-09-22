# Textract Results

Code and data for *"Validation of Automated Table Extraction for Historical Infectious-Disease Surveillance Data"* (Nalian, Earn, & Walker, 2026; retitled from "Automated Extraction of Infectious Disease Data from Historical Documents" under Ticket T2/3-A, item 17), which assesses Amazon Textract as a tool for digitizing the 1956 Canada Notifiable Disease Dataset (CNDD).

This repository contains everything needed to reproduce the figures and tables in the paper from the PDFs of the source tables.

## Repository layout

```
Textract_Results/
├── data/
│   ├── pdfs/{1956,1957,1958}/           Weekly CNDD tables, scanned PDFs
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
└── figures/                             Generated figures
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

Open `postprocessing/combine.ipynb` and **Run All**

Output:
- `data/analysis_intermediates/Levels_of_Accuracy.csv` (one row per cell)
- `data/analysis_intermediates/rows_with_no_equality.csv` (mismatched cells with Levenshtein distance)

The notebook also prints the four equality-progression percentages from Section 5.1.1.

### Step 4. Generate the figures

```bash
python analysis/plot_levenshtein.py   # Figs 4, 5
python analysis/row_sum_check.py      # Figs 7, 9
python analysis/timeseries_plots.py   # Figs 10, 12, 13, 15, 20, 21
Rscript analysis/cross_correlation.R  # Figs 11, 14, 16 + Tables 1, 2, 3
Rscript analysis/growthrates.R        # Figs 17, 18 + Tables 4, 5
Rscript analysis/boxplots.R           # Fig 22
```

Each script header documents its own inputs/outputs; see the [Figure and table index](#figure-and-table-index) below for the full mapping.

### Step 5. Manual correction ("hardcoding") of the Meningitis and Mumps series

Two of the three cross-correlation comparisons (Measles-vs-Meningitis, Chickenpox-vs-Mumps — paper Tables 2/3 and Figs 12–16) are **not** computed from the raw output of Step 3/4. They use a manually corrected Textract series instead:

- `data/timeseries/meningitis_measles/1956-1958_textract_hardcoded.csv`
- `data/timeseries/chickenpox_mumps/1956-1958_textract_timeseries_hardcoded.csv`

**This step is not scripted.** These two files were produced by hand: large, isolated spikes in the raw Textract series (visible via `analysis/boxplots.R`'s violin plots, Fig 22) were checked against the source scans and corrected in place. This is described in the paper as §5.3 ("Remarks on Dataset Specific Coding") and disclosed as a leakage/generalizability limitation in §6.2. If you need to regenerate these files (e.g. after re-running Textract from scratch), you must repeat that manual review — there is no automated equivalent in this repository. The Measles-vs-Chickenpox comparison (Table 1, Fig 10/11) deliberately does **not** go through this step, so it reflects the pipeline's automated output only; see the [reconciliation notes](#manuscript-reconciliation-august-2026) below for why that made it the one comparison sensitive to upstream pipeline changes.

### Step 6. Cross-correlation and peak-comparison summary statistics (Ticket T2-7)

```bash
python analysis/ccf_summary.py   # CCF summary table + per-lag SI tables
Rscript analysis/growthrates.R   # already run in Step 4; also regenerates Table 4/5 with the new schema
```

`analysis/ccf_summary.py` reads the three per-lag CCF CSVs from Step 4 and replaces the unstable relative-difference metric with stable summary statistics (max absolute difference, RMS difference, peak lag/correlation for each source, and the change between them). Sign convention throughout: **difference = Textract − Manual**. Outputs:

- `data/analysis_intermediates/ccf_summary.csv` — one row per disease pair, feeds the paper's main-text CCF summary table
- `data/analysis_intermediates/ccf_per_lag_si.csv` — per-lag values (Lag, Manual, Textract, Difference), feeds the paper's Supporting Information tables S1–S3

The script asserts its recomputed values match the pre-existing per-lag CSVs to 4 dp before proceeding (per T2-7 §7); it also checks for ties in the peak-lag / max-abs-diff metrics (none were found for any of the three disease pairs).

### Step 7. Growth-rate and doubling-time reporting (Ticket T2-8)

```bash
Rscript analysis/growthrates.R   # same script as Step 4/6; now also writes growth_rate_summary.csv
```

T2-8 required either reporting the growth rate `r` (not just the doubling time `Td`) with full model specification and uncertainty, or removing the growth-rate claims entirely. We took the reporting path. `analysis/growthrates.R` now also emits:

- `data/analysis_intermediates/growth_rate_summary.csv` — one row per disease × window × source, with `r` (per week) and its 95% CI, `Td` (weeks) and its 95% CI, `n_obs` per fitting window, convergence status, and `Delta_r` / `Delta_Td` (Textract − Manual, same sign convention as T2-7)

T2-8 §2.1 flagged something that needed resolving before any of this could be reported: Figs 17–18 annotate an "initial doubling time" that is identical to four significant figures across both fitting windows, for every disease and every source. T2-8 listed three possible causes (model pooling across windows, a plotting/labelling bug, or coincidence) and required determining which before populating any table. This was already established while fixing the T2-7 doubling-time bug (see [Part 2](#manuscript-reconciliation-part-2-ticket-t2-7-august-2026) above): the model's `formula_parameters` are left at their default `~1` for every top-level parameter including `log(r)`, so `egf()` estimates a single growth rate shared across both fitting windows, not one rate per window. Cause 1 (model pooling), not a bug. This is now stated explicitly in the paper (Methods model-specification paragraph, and the Fig 17/18 captions) rather than left for a reader to notice on their own.

**Not run: multi-data-version growth-rate comparison.** T2-8 §6 asks for the fits to be re-run on "each available data version (raw, processed, manually corrected)" for at least Measles, to check whether the growth-rate estimate is stable across pipeline stages. We checked, and this isn't possible with the data currently in the repository: the only Textract series available for Measles and Chickenpox is the Stage-2 processed one (`1956-1958_textract_timeseries_chickenpox_measles.csv`); the "manually corrected" (hardcoded) treatment was applied only to the Meningitis and Mumps series (Step 5 above), never to Measles or Chickenpox, and there is no separately-saved "raw" (pre-Stage-2) version of the Measles/Chickenpox timeseries distinct from the processed one — `1956-1958_textract_chickenpox_measles.csv` in the same folder is the same data in long format, not an earlier pipeline stage. This is disclosed as a scope limitation in the paper (§6.2) rather than worked around by fabricating a data version that doesn't exist.

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
| Table 1 (accuracy pipeline, `tab:pipeline`) | `postprocessing/combine.ipynb` | `data/analysis_intermediates/accuracy_summary.csv` |
| Table 2 (Levenshtein distance, `tab:lev_dist`) | `postprocessing/combine.ipynb` | `data/analysis_intermediates/rows_with_no_equality.csv` |
| Table 3 (CCF summary across all three disease pairs, `tab:ccf_summary`) | `analysis/ccf_summary.py` | `data/analysis_intermediates/ccf_summary.csv` |
| Table 4 (Measles peak + growth-rate comparison) | `analysis/growthrates.R` | `data/analysis_intermediates/table4_measles_peak_comparison.csv`, `growth_rate_summary.csv` |
| Table 5 (Chickenpox peak + growth-rate comparison) | `analysis/growthrates.R` | `data/analysis_intermediates/table5_chickenpox_peak_comparison.csv`, `growth_rate_summary.csv` |
| Supplementary Table S1 (Measles vs Chickenpox per-lag CCF diffs) | `analysis/cross_correlation.R` | `data/analysis_intermediates/table1_measles_chickenpox_ccf_diff.csv` |
| Supplementary Table S2 (Measles vs Meningitis per-lag CCF diffs) | `analysis/cross_correlation.R` | `data/analysis_intermediates/table2_measles_meningitis_ccf_diff.csv` |
| Supplementary Table S3 (Chickenpox vs Mumps per-lag CCF diffs) | `analysis/cross_correlation.R` | `data/analysis_intermediates/table3_chickenpox_mumps_ccf_diff.csv` |

Screenshots used as Figures 1, 2, 3, 6, 8, and 19 are not generated by code; they live under `figures/screenshots/`.

## Note on Section 5.1.1 percentages

Earlier drafts of the paper reported a progression of cell-match percentages from 71% (strict equality) up to a headline of "approximately 97%" (all criteria combined). That 97% figure was never reproducible from this pipeline and has been removed from the manuscript (see [Manuscript reconciliation](#manuscript-reconciliation-august-2026) below). The verified numbers, reproducible by running `postprocessing/combine.ipynb` end to end (or the equivalent script described there), are:

| Equality criterion              | All cells (n = 53,872) | Numeric, manual reference (n = 28,255) | Numeric, both sources (n = 26,069) |
|---------------------------------|------------------------:|------------------------------------:|---------------------------------:|
| Strict equality (content + position) | 73.98%             | 71.89%                              | 77.92%                           |
| + Commas/spaces normalized      | 76.84%                  | 77.32%                              | 83.80%                           |
| + Row-shift tolerated (content-only, adjacent column) | 88.53% | 92.95%                       | 95.58%                     |

(M1) The primary numeric-accuracy figure used in the paper is now the "Numeric, manual reference" column, since it does not silently exclude cells where Textract failed to extract a number at all -- the more defensible base rate. The "Numeric, both sources" column is retained as a secondary figure. Both denominators, for all three criteria, are exported by `postprocessing/combine.ipynb` to `data/analysis_intermediates/accuracy_summary.csv`.

The "All cells" column counts every cell in every 1956 weekly table (53,872 cells total), including dashes (used in the source PDFs to mean *zero cases*) and dots (used to mean *missing data*), which match trivially between Textract and the manual data and tell us nothing about Textract's accuracy. The "Numeric-only" column restricts the comparison to the 26,069 cells where both Textract and the manual entry contain numeric values, i.e. the substantive question: of the cells that hold actual disease counts, how many did Textract read correctly? This numeric-only, row-shift-tolerant figure (95.58%, "approximately 96%") is the closest verified analogue to the paper's original 97% headline and is what the current manuscript now cites.

There is no separate "numeric cells only, headers excluded" or "row-shift only" percentage distinct from the two rows above — the script computes exactly these three equality criteria (`Equal`, `Equal_No_Commas_No_Spaces`, `Equal_Shifted`) under both denominators. `Equal_Shifted` already folds in comma/space normalization, so it is reported here as "content-only, cumulative" rather than as an independent row-shift-only figure.

Of the 53,872 evaluated cells, **6,177 (11.5%)** are true extraction errors under the row-shift-tolerant criterion. See `data/analysis_intermediates/rows_with_no_equality.csv` and Table 1 of the paper for their Levenshtein-distance distribution (mean distance 1.84; 38.1% at distance 1, 51.7% at distance 2).

## Manuscript reconciliation (August 2026)

An August 2026 audit re-ran every script in this pipeline against the data currently checked into `data/` and compared the output to the numbers then written in `Eden_4P06/ms2.tex`. Several headline numbers in the manuscript had drifted out of sync with the underlying data/code (most likely because the manuscript text was drafted against an earlier snapshot of the cleaning pipeline). All of the following have been corrected in `Eden_4P06/ms2.tex`; **the corrected values below are the current source of truth**, verified reproducible by re-running the relevant script twice and diffing the output.

| What | Manuscript said | Verified value | Source |
|---|---|---|---|
| Headline cell agreement | "~97%" | 88.5% (all cells) / **92.9%** (numeric in manual reference, primary) / 95.6% (numeric on both sides, secondary), content-only after row-shift tolerance | `postprocessing/combine.ipynb` → `Levels_of_Accuracy.csv`, `accuracy_summary.csv` |
| True extraction errors (Table 1 denominator) | 1,334 | **6,177** of 53,872 (11.5%) | `rows_with_no_equality.csv` |
| Levenshtein distance distribution (Table 1) | distances 1 and 2 roughly tied (~37% each) | distance 2 is the plurality (51.7%), distance 1 is 38.1% | `rows_with_no_equality.csv` |
| Worked outlier example (disease-name string error) | "(e) Other venereal diseases" cell, Levenshtein 11 | that exact cell no longer appears in the mismatched set; replaced with a verified example (a 25-dot placeholder run vs. reference value 68) | `rows_with_no_equality.csv`, rows with `Lev_Dist >= 8` |
| Measles vs. Chickenpox CCF (Table 1 of the paper — not to be confused with the Levenshtein table also numbered "Table 1" in early drafts) | e.g. lag −12: Textract = 0.0121 | Textract = 0.0244 | `analysis/cross_correlation.R` → `table1_measles_chickenpox_ccf_diff.csv` |
| Measles peak comparison (paper Table 4) | Window 1: Manual 64/2102, Textract 64/2183 | Manual 64/**1967**, Textract 64/**2161** | `analysis/growthrates.R` → `table4_measles_peak_comparison.csv` |
| Chickenpox peak comparison (paper Table 5) | Window 1: weeks 60/61 | weeks **64/64** (both sources) | `analysis/growthrates.R` → `table5_chickenpox_peak_comparison.csv` |
| Row-sum outlier week (Measles, §5.1.3 narrative) | "Week 8" in body text | **Week 9** (matches the figure's own caption and `measles_tables_check.csv`) | `analysis/row_sum_check.py` → `measles_tables_check.csv` |

Notably, the Meningitis-vs-Measles and Chickenpox-vs-Mumps CCF tables (paper Tables 2 and 3) **did** reproduce exactly against current data and needed no changes — only the Measles-vs-Chickenpox comparison (Table 1) had drifted. This is consistent with the pipeline: Tables 2 and 3 are computed from the `*_hardcoded` Textract series (manually corrected, see [Step 5](#step-5-manual-correction-hardcoding-of-the-meningitis-and-mumps-series) above), which is a fixed, checked-in artifact, whereas Table 1 uses the unhardcoded Textract series, which is sensitive to any change upstream in the cleaning step.

**Not yet reconciled / needs author follow-up:**
- A full Textract-vs-reference-transcription-vs-ambiguous-source disagreement taxonomy for the 6,177 mismatched cells (would require adjudicating a sample against the source scans; the Wilson-interval machinery for this already exists in `agreement.py` at the repo root — a standalone script, not yet wired into the numbered pipeline steps above, that recomputes agreement directly from `data/textract_raw|cleaned` vs `data/manual|manual_cleaned` and reports Wilson confidence intervals).
- The embedded figures under `Eden_4P06/figure/` (e.g. `Lev_dist.pdf`, `normalized_L.png`) were not regenerated as part of this audit and may not reflect the corrected data above — regenerate them with the [Step 4](#step-4-generate-the-figures) commands above and copy the outputs into `Eden_4P06/figure/`.

## Manuscript reconciliation, part 2 (Ticket T2-7, August 2026)

Ticket T2-7 asked for the unstable relative-difference columns in the CCF and peak-comparison tables to be replaced with stable summary statistics (max/RMS absolute difference, signed peak-lag and peak-week deltas, etc.) — see [Step 6](#step-6-cross-correlation-and-peak-comparison-summary-statistics-ticket-t2-7) above for the new script. Implementing it surfaced a second, independent bug, this time in `analysis/growthrates.R`: the pre-existing `doubling_times()` function called `fitted(fit, top = "log(r)", se = TRUE)` expecting a `value`/`se` column back, but in the installed `epigrowthfit` version (0.15.5) that call returns a bare matrix with no standard-error column at all, so the function's output was always non-numeric. This was never surfaced in practice because the only caller (`plot_growth()`) wraps it in a `tryCatch` and silently falls back to `epigrowthfit`'s default plot method on any error — so every doubling-time confidence interval ever annotated on Figs 17–18 by the "custom" plot path was silent dead code, not a computed value. Fixed by reading `coef()`/`confint()` on the fitted model's `log(r)` parameter directly, which does carry a Wald CI.

While fixing this we also confirmed empirically that the growth-rate model fits a single shared rate parameter across both peak-fitting windows (the formula for every top-level parameter defaults to `~1`, with no per-window term) — so a given source (Manual or Textract) has one doubling-time estimate, not one per window. Table 4/5 in the paper now reflect this explicitly rather than implying two independent per-window estimates.

The real (now verified) doubling times differ substantially from the placeholder values that had been quoted in the T2-7 ticket text itself as already-computed ("Measles 6.4 (4.9, 8.5) manual vs 6.1 (4.7, 8.0) Textract"): the actual computed values are Measles 5.1 (4.2, 6.1) manual vs. 5.6 (4.5, 6.9) Textract, and Chickenpox 4.8 (4.2, 5.5) vs. 4.8 (3.6, 6.4). This is the same pattern as the [Part 1 reconciliation](#manuscript-reconciliation-august-2026) above: numbers quoted in planning/ticket documents should be treated as claims to verify against the pipeline, not as a source of truth, even when the document says the numbers "already exist."

## Manuscript reconciliation, part 3 (Modest fixes M1-M6, September 2026)

A further pass (ticket M1-M6) made the following additional corrections, on top of Parts 1 and 2 above:

- **M1** (reference-defined accuracy denominator): `postprocessing/combine.ipynb` now also computes agreement using "numeric in the manual reference" as the denominator (n=28,255; 92.95% under the row-shift-tolerant criterion), exported alongside the existing "numeric on both sides" denominator to `data/analysis_intermediates/accuracy_summary.csv`. This is now the manuscript's primary numeric-accuracy figure; see the table above.
- **M2** (excluded cells): the 53,872-cell evaluated overlap excludes 7,244 cells present in the full 61,116-cell cleaned Textract bounding grids (61,116 = sum of row x column extent across the 52 cleaned 1956 Textract tables). This is now disclosed in the manuscript Methods; it is not automatically 7,244 additional errors (could include padding rows, repeated headers, or other structural artefacts of aligning the two independently formatted tables).
- **M3** (CCF sign convention and calendar-week alignment): `analysis/cross_correlation.R`'s `Difference` column previously computed Manual - Textract, contradicting the Textract-minus-Manual convention stated throughout the manuscript; fixed. More importantly, the script computed each source's cross-correlation after dropping missing values *independently* per source, so the manual and Textract series being compared at a given disease pair could cover different sets of calendar weeks (and internal missing weeks were silently compressed by position). Fixed by merging manual and Textract on their shared `Row` (week) identifier first and restricting to weeks with complete data on both sides before computing either source's CCF. All three CCF tables changed as a result; the Measles-vs-Meningitis peak lag in particular moved from (-9, -11) to (3, 2) under the corrected alignment.
- **M4**: growth-rate reporting confirmed unchanged from Part 2 above (re-ran and diffed byte-for-byte against the committed `growth_rate_summary.csv`; identical).
- **M5**: `analysis/ccf_summary.py` and `growth_rate_summary.csv` were already present in the repository as of this pass (see Parts 1-2 above); this pass fixed the `cross_correlation.R` sign bug described under M3, and re-verified `ccf_summary.py`'s consistency check now agrees in both sign and magnitude with the fixed R script's output. The manuscript Data Availability statement now states the repository URL directly (previously it appeared only in the S2 Text supplementary "Repository" entry).

**Needs Eden (not attempted -- would require Textract access or data not present in the repo):**
- Raw Textract API JSON responses, the AWS region/account/config used, the exact extraction date(s), and installed package versions at extraction time are not present anywhere in this repository. Only the *processed* CSV outputs are checked in. If these numbers are ever cited as "reproducible from this repository," they are not, and this should be flagged in the manuscript's Textract-provenance discussion (Methods / Supporting Information) rather than reconstructed or guessed.
- An archived DOI (e.g., Zenodo) for a tagged release: this repository has no tags/releases as of this pass, so no DOI exists to cite; minting one was explicitly out of scope.

## Acknowledgements

Source data: Canada Notifiable Disease Dataset (Dominion Bureau of Statistics, 1956). Manually-entered transcriptions courtesy of McMaster University's Theoretical Biology group.
