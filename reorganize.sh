#!/usr/bin/env bash
# reorganize.sh
# Run this from the root of your Textract_Results repo.
# It moves files into a clean structure and deletes everything not needed
# to reproduce the paper. It does NOT modify the contents of any kept file.
#
# Usage:
#   cd ~/Desktop/Textract_Results
#   bash reorganize.sh
#
# Then review with `git status`, and if happy:
#   git add -A
#   git commit -m "Reorganize repo: keep only paper-essential files"
#   git push

set -e

echo "==> Sanity check: are we at the repo root?"
if [ ! -d ".git" ]; then
  echo "ERROR: No .git directory found. Run this from the repo root."
  exit 1
fi

echo ""
echo "==> Creating new directory structure..."
mkdir -p \
  data/pdfs/1956 data/pdfs/1957 data/pdfs/1958 \
  data/source_xlsx \
  data/manual/1956 data/manual/1957 data/manual/1958 \
  data/textract_raw/1956 data/textract_raw/1957 data/textract_raw/1958 \
  data/timeseries/measles_chickenpox \
  data/timeseries/meningitis_measles \
  data/timeseries/chickenpox_mumps \
  data/analysis_intermediates \
  extraction \
  postprocessing \
  analysis \
  figures/screenshots

echo ""
echo "==> Moving PDFs..."
mv "Textract Pipeline Experiments/cdi_ca_1956_wk_prov_dbs_Parts/"*.pdf data/pdfs/1956/
mv 1957/1957week_*.pdf data/pdfs/1957/
mv 1958/1958week_*.pdf data/pdfs/1958/

echo "==> Moving source xlsx files..."
mv cdi_ca_1956_wk_prov_dbs.xlsx data/source_xlsx/
mv 1957_Manual/cdi_ca_1957_wk_prov_dbs.xlsx data/source_xlsx/
mv 1958_Manual/cdi_ca_1958_wk_prov_dbs.xlsx data/source_xlsx/

echo "==> Moving manual CSVs..."
mv 1956_Manual_csv/*.csv data/manual/1956/
mv 1957_Manual_csv/*.csv data/manual/1957/
mv 1958_Manual_csv/*.csv data/manual/1958/

echo "==> Moving raw Textract CSVs (keeping only *_tables.csv, dropping *_confidences.csv)..."
mv "Textract Pipeline Experiments/CleanedCSVs/"*_tables.csv data/textract_raw/1956/
rm "Textract Pipeline Experiments/CleanedCSVs/"*_confidences.csv
mv 1957_output/*.csv data/textract_raw/1957/
mv 1958_output/*.csv data/textract_raw/1958/

echo "==> Moving aggregated time-series CSVs..."
mv measles_chickenpox/*.csv data/timeseries/measles_chickenpox/
mv meningitis_measles/*.csv data/timeseries/meningitis_measles/
mv 1956-1958_manual_chickenpox_mumps.csv data/timeseries/chickenpox_mumps/
mv 1956-1958_textract_chickenpox_mumps.csv data/timeseries/chickenpox_mumps/
mv 1956-1958_manual_timeseries_chickenpox_mumps.csv data/timeseries/chickenpox_mumps/
mv 1956-1958_textract_timeseries_chickenpox_mumps.csv data/timeseries/chickenpox_mumps/
mv 1956-1958_textract_timeseries_hardcoded.csv data/timeseries/chickenpox_mumps/

echo "==> Dropping per-year meningitis_measles intermediates (1956-1958 aggregates supersede them)..."
rm data/timeseries/meningitis_measles/195[678]_*.csv

echo "==> Moving analysis intermediate CSVs (needed for Figs 4, 5, 7, 9)..."
mv "Textract Pipeline Experiments/Levels_of_Accuracy.csv" data/analysis_intermediates/
mv "Textract Pipeline Experiments/rows_with_no_equality.csv" data/analysis_intermediates/
mv chickenpox_tables_check.csv data/analysis_intermediates/
mv measeles_tables_check.csv data/analysis_intermediates/

echo "==> Moving extraction scripts..."
mv AWS_Python_Table_Extraction.py extraction/
mv xlsx_to_csvs.py extraction/
rm "Textract Pipeline Experiments/AWS_Python_Table_Extraction.py"   # byte-identical duplicate

echo "==> Moving postprocessing scripts..."
mv "Textract Pipeline Experiments/Cleaning_fixed.ipynb" postprocessing/
mv "Textract Pipeline Experiments/combine.ipynb" postprocessing/
mv "Textract Pipeline Experiments/combine disease.py" "postprocessing/combine_disease.py"

echo "==> Moving analysis scripts..."
mv row_sum_check.py analysis/
mv "Textract Pipeline Experiments/plot.py" analysis/
mv "Textract Pipeline Experiments/Cross-correlation.py" analysis/
mv "Textract Pipeline Experiments/plot.ipynb" analysis/
mv crossCorrelation.R analysis/
mv cc.R analysis/
mv growthrates.R analysis/
mv loess.R analysis/
mv loesspeaks.R analysis/
mv boxplots.R analysis/

echo ""
echo "==> Deleting abandoned LLM approach (Section 6.2 says it was dropped)..."
rm -rf "LLM Findings"

echo "==> Deleting Quebec dataset (only Fig 3 uses it, and Fig 3 is a screenshot)..."
rm -rf QC_1927-1931 MontrealOnly.csv cdi_qc_1927-31_mn_county_combined.csv

echo "==> Deleting Compare/ and Textract/ (early prototypes / duplicates)..."
rm -rf Compare Textract

echo "==> Deleting aws-textract-steve-test (sandbox)..."
rm -rf aws-textract-steve-test

echo "==> Removing now-empty year folders..."
rm -f 1957/cdi_ca_1957_wk_prov_dbs.pdf     # unsplit 1957 PDF - we have per-week
rmdir 1957 1958 1957_Manual 1958_Manual 1957_output 1958_output \
      1956_Manual_csv 1957_Manual_csv 1958_Manual_csv \
      measles_chickenpox meningitis_measles 2>/dev/null || true

echo "==> Deleting duplicate 1956 CSV folder..."
rm -rf cdi_ca_1956_wk_prov_dbs_csvs

echo "==> Deleting root-level intermediate/debug files..."
# Per-year combine outputs - 1956-1958 aggregates in data/timeseries/ supersede these
rm -f 1956_output.csv 1957_textract_output.csv 1958_textract_output.csv
rm -f 1957_manual_chickenpox_mumps.csv 1958_manual_chickenpox_mumps.csv
rm -f 1957_textract_chickenpox_mumps.csv 1958_textract_chickenpox_mumps.csv
# Per-disease check files for diseases not analyzed in the paper
rm -f chickenpox_tables_check_without1.csv
rm -f influenza_tables_check_without.csv influenza_tables_check_without1.csv
rm -f mumps_tables_check.csv rubella_tables_check.csv scarletFever_tables_check.csv
rm -f smallpox_tables_check.csv venerealDiseases_tables_check.csv whoppingCough_tables_check.csv
# Debug/scratch
rm -f debug_with_file.csv debug_with_file_sorted.csv textract_bad_rows.csv
# Meta files not part of the paper
rm -f Updates.md notes-meeting-noah.md eden.Rproj
# Unsplit combined PDF (we have per-week PDFs)
rm -f cdi_ca_1958_wk_prov_dbs.pdf
# Old root cleaned CSV (early prototype output)
rm -f cdi_ca_1956_wk_prov_dbs_cleaned.csv

echo "==> Deleting Textract Pipeline Experiments/ folder (all remaining intermediates regenerable)..."
rm -rf "Textract Pipeline Experiments"

echo ""
echo "================================================================"
echo "Done. Final structure:"
echo "================================================================"
find . -maxdepth 2 -type d -not -path "./.git*" | sort
echo ""
echo "Top-level files at root:"
ls -1 *.* 2>/dev/null || echo "  (none)"
echo ""
echo "Next steps:"
echo "  git status              # review the changes"
echo "  git add -A"
echo "  git commit -m \"Reorganize repo into clean paper-reproducible structure\""
echo "  git push"
