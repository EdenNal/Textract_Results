# Textract Results

Code and data for *"Automated Extraction of Infectious Disease Data from Historical Documents"* (Nalian, Earn, & Walker, 2026), which assesses Amazon Textract as a tool for digitizing the 1956 Canada Notifiable Disease Dataset (CNDD).

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

The cleaning step strips preamble rows and pads short rows so every row in a weekly file has the same column count. Open `postprocessing/Cleaning_fixed.ipynb` and **Run All**
```

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
| Table 1 (Measles vs Chickenpox CCF diffs) | `analysis/cross_correlation.R` | `data/timeseries/measles_chickenpox/` |
| Table 2 (Measles vs Meningitis CCF diffs) | `analysis/cross_correlation.R` | `data/timeseries/meningitis_measles/` |
| Table 3 (Chickenpox vs Mumps CCF diffs) | `analysis/cross_correlation.R` | `data/timeseries/chickenpox_mumps/` |
| Table 4 (Measles peak comparison) | `analysis/growthrates.R` | (printed to console) |
| Table 5 (Chickenpox peak comparison) | `analysis/growthrates.R` | (printed to console) |

Screenshots used as Figures 1, 2, 3, 6, 8, and 19 are not generated by code; they live under `figures/screenshots/`.

## Note on Section 5.1.1 percentages

The paper reports a progression of cell-match percentages from 71% (strict equality) to 97% (all equality criteria combined) in Section 5.1.1. The pipeline in this repository reports these in two ways, both printed by `postprocessing/combine.ipynb`:

| Equality criterion              | Paper | All cells | Numeric cells |
|---------------------------------|------:|----------:|--------------:|
| Strict equality                 | 71%   | 74.12%    | 79.03%        |
| + Commas/spaces normalized      | 75%   | 76.92%    | 84.61%        |
| + Numeric-only equality         | 80%   |           |               |
| + Row-shift tolerated           | 85%   |           |               |
| All criteria combined           | 97%   | 88.02%    | **95.77%**    |

The "All cells" column counts every cell in every weekly table (56,784 cells), including dashes (used in the source PDFs to mean *zero cases*) and dots (used to mean *missing data*), which match trivially between Textract and the manual data and tell us nothing about Textract's accuracy. The "Numeric cells" column restricts the comparison to the 27,490 cells where both Textract and the manual entry contain numeric values, i.e. the substantive question: of the cells that hold actual disease counts, how many did Textract read correctly?

## Acknowledgements

Source data: Canada Notifiable Disease Dataset (Dominion Bureau of Statistics, 1956). Manually-entered transcriptions courtesy of McMaster University's Theoretical Biology group.
