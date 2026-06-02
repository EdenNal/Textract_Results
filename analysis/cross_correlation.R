# Cross-correlation analysis for Section 5.2.1 of the paper.
#
# Produces:
#   Fig 11  CCF: Measles vs Chickenpox  (manual and Textract panels)
#   Fig 14  CCF: Measles vs Meningitis  (manual and Textract panels)
#   Fig 16  CCF: Chickenpox vs Mumps    (manual and Textract panels)
#
# Plus the per-lag difference tables that appear in the paper as
# Tables 1, 2, and 3.
#
# Inputs:
#   data/timeseries/measles_chickenpox/1956-1958_manual_timeseries_chickenpox_measles.csv
#   data/timeseries/measles_chickenpox/1956-1958_textract_timeseries_chickenpox_measles.csv
#   data/timeseries/meningitis_measles/1956-1958_manual_timeseries_meningitis_measles.csv
#   data/timeseries/meningitis_measles/1956-1958_textract_hardcoded.csv
#   data/timeseries/chickenpox_mumps/1956-1958_manual_timeseries_chickenpox_mumps.csv
#   data/timeseries/chickenpox_mumps/1956-1958_textract_timeseries_hardcoded.csv
#
# Outputs:
#   figures/fig11_measles_chickenpox_ccf.png
#   figures/fig14_measles_meningitis_ccf.png
#   figures/fig16_chickenpox_mumps_ccf.png
#   data/analysis_intermediates/table1_measles_chickenpox_ccf_diff.csv
#   data/analysis_intermediates/table2_measles_meningitis_ccf_diff.csv
#   data/analysis_intermediates/table3_chickenpox_mumps_ccf_diff.csv
#
# Usage (from repo root):
#   Rscript analysis/cross_correlation.R

suppressPackageStartupMessages({
  library(ggplot2)
})

# ---- Paths ----
script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) getwd()
)
repo_root <- normalizePath(file.path(script_dir, ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "data"))) repo_root <- getwd()

ts_dir  <- file.path(repo_root, "data", "timeseries")
fig_dir <- file.path(repo_root, "figures")
int_dir <- file.path(repo_root, "data", "analysis_intermediates")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(int_dir, recursive = TRUE, showWarnings = FALSE)

LAG_MAX <- 12

# ---- Helpers ----

compute_ccf_df <- function(csv_file, x_col, y_col, lag_max = LAG_MAX) {
  df <- read.csv(csv_file, check.names = FALSE)
  stopifnot(x_col %in% names(df), y_col %in% names(df))

  x <- as.numeric(df[[x_col]])
  y <- as.numeric(df[[y_col]])
  keep <- complete.cases(x, y)
  x <- as.numeric(scale(x[keep]))
  y <- as.numeric(scale(y[keep]))

  cc <- ccf(x, y, lag.max = lag_max, plot = FALSE)
  data.frame(Lag = as.vector(cc$lag),
             Correlation = as.vector(cc$acf),
             N = length(x))
}

plot_ccf_panel <- function(ccf_df, title, subtitle) {
  conf <- 2 / sqrt(ccf_df$N[1])
  ggplot(ccf_df, aes(x = Lag, y = Correlation)) +
    geom_hline(yintercept = 0, color = "black") +
    geom_segment(aes(xend = Lag, yend = 0), linewidth = 1.1) +
    geom_hline(yintercept = c(-conf, conf), linetype = "dashed", color = "red") +
    theme_minimal(base_size = 14) +
    labs(title = title, subtitle = subtitle,
         x = "Lag (weeks)", y = "Cross-correlation") +
    theme(plot.title = element_text(face = "bold"),
          panel.grid.minor = element_blank())
}

# Build the CCFs, write the side-by-side figure, return the difference table.
process_pair <- function(manual_file, textract_file, x_col, y_col,
                         pair_label, fig_path, table_path) {
  manual_df   <- compute_ccf_df(manual_file,   x_col, y_col)
  textract_df <- compute_ccf_df(textract_file, x_col, y_col)

  p_manual <- plot_ccf_panel(
    manual_df,
    title    = paste0("Cross-Correlation: ", x_col, " vs ", y_col),
    subtitle = "Weekly data (1956-1958), Manual data"
  )
  p_textract <- plot_ccf_panel(
    textract_df,
    title    = paste0("Cross-Correlation: ", x_col, " vs ", y_col),
    subtitle = "Weekly data (1956-1958), Textract data"
  )

  # Combine the two panels side-by-side. Use cowplot or patchwork if installed;
  # otherwise fall back to writing both panels to a 2-page PDF via gridExtra,
  # or in the last resort just save them as separate PNGs.
  saved <- FALSE
  if (requireNamespace("patchwork", quietly = TRUE)) {
    combined <- p_manual + p_textract
    ggsave(fig_path, combined, width = 12, height = 5, dpi = 150)
    saved <- TRUE
  } else if (requireNamespace("gridExtra", quietly = TRUE)) {
    g <- gridExtra::arrangeGrob(p_manual, p_textract, ncol = 2)
    ggsave(fig_path, g, width = 12, height = 5, dpi = 150)
    saved <- TRUE
  }
  if (!saved) {
    # Fallback: save the two panels individually with a "_manual"/"_textract" suffix.
    ggsave(sub("\\.png$", "_manual.png",   fig_path), p_manual,   width = 6, height = 5, dpi = 150)
    ggsave(sub("\\.png$", "_textract.png", fig_path), p_textract, width = 6, height = 5, dpi = 150)
    message("Note: install 'patchwork' or 'gridExtra' for a combined two-panel figure.")
  }
  message("Wrote figure: ", fig_path)

  # Build the difference table (manual vs textract per lag).
  diff_df <- merge(
    data.frame(Lag = manual_df$Lag,   Manual   = manual_df$Correlation),
    data.frame(Lag = textract_df$Lag, Textract = textract_df$Correlation),
    by = "Lag", all = TRUE
  )
  diff_df$Difference           <- diff_df$Manual - diff_df$Textract
  diff_df$Relative_Difference  <- diff_df$Difference / diff_df$Manual

  write.csv(diff_df, table_path, row.names = FALSE)
  message("Wrote table:  ", table_path)

  invisible(diff_df)
}

# ---- Run the three disease pairs ----

# Fig 11 / Table 1: Measles vs Chickenpox
process_pair(
  manual_file   = file.path(ts_dir, "measles_chickenpox",
                            "1956-1958_manual_timeseries_chickenpox_measles.csv"),
  textract_file = file.path(ts_dir, "measles_chickenpox",
                            "1956-1958_textract_timeseries_chickenpox_measles.csv"),
  x_col       = "Measles",
  y_col       = "Chickenpox",
  pair_label  = "measles_chickenpox",
  fig_path    = file.path(fig_dir, "fig11_measles_chickenpox_ccf.png"),
  table_path  = file.path(int_dir, "table1_measles_chickenpox_ccf_diff.csv")
)

# Fig 14 / Table 2: Measles vs Meningitis (Textract uses the hardcoded series)
process_pair(
  manual_file   = file.path(ts_dir, "meningitis_measles",
                            "1956-1958_manual_timeseries_meningitis_measles.csv"),
  textract_file = file.path(ts_dir, "meningitis_measles",
                            "1956-1958_textract_hardcoded.csv"),
  x_col       = "Measles",
  y_col       = "Meningitis",
  pair_label  = "measles_meningitis",
  fig_path    = file.path(fig_dir, "fig14_measles_meningitis_ccf.png"),
  table_path  = file.path(int_dir, "table2_measles_meningitis_ccf_diff.csv")
)

# Fig 16 / Table 3: Chickenpox vs Mumps (Textract uses the hardcoded series)
process_pair(
  manual_file   = file.path(ts_dir, "chickenpox_mumps",
                            "1956-1958_manual_timeseries_chickenpox_mumps.csv"),
  textract_file = file.path(ts_dir, "chickenpox_mumps",
                            "1956-1958_textract_timeseries_hardcoded.csv"),
  x_col       = "Chickenpox",
  y_col       = "Mumps",
  pair_label  = "chickenpox_mumps",
  fig_path    = file.path(fig_dir, "fig16_chickenpox_mumps_ccf.png"),
  table_path  = file.path(int_dir, "table3_chickenpox_mumps_ccf_diff.csv")
)

message("Done.")
