# Initial growth rates and peak comparisons for Section 5.2.2 of the paper.
#
# Produces:
#   Fig 17  Measles time series with epigrowthfit's doubling-time windows
#           (manual + textract panels)
#   Fig 18  Chickenpox time series with epigrowthfit's doubling-time windows
#           (manual + textract panels)
#   Table 4 Manual-vs-Textract peak comparison (week, cases, % differences)
#           for Measles
#   Table 5 Same comparison for Chickenpox
#
# Inputs:
#   data/timeseries/measles_chickenpox/1956-1958_manual_timeseries_chickenpox_measles.csv
#   data/timeseries/measles_chickenpox/1956-1958_textract_timeseries_chickenpox_measles.csv
#
# Outputs:
#   figures/fig17_measles_growth_rates.png
#   figures/fig18_chickenpox_growth_rates.png
#   data/analysis_intermediates/table4_measles_peak_comparison.csv
#   data/analysis_intermediates/table5_chickenpox_peak_comparison.csv
#
# Usage (from repo root):
#   Rscript analysis/growthrates.R

suppressPackageStartupMessages({
  library(epigrowthfit)
  library(dplyr)
})

# ---- Paths ----
script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) getwd()
)
repo_root <- normalizePath(file.path(script_dir, ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "data"))) repo_root <- getwd()

ts_dir  <- file.path(repo_root, "data", "timeseries", "measles_chickenpox")
fig_dir <- file.path(repo_root, "figures")
int_dir <- file.path(repo_root, "data", "analysis_intermediates")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(int_dir, recursive = TRUE, showWarnings = FALSE)

# ---- Analysis windows (week ranges of the two epidemic peaks) ----
WINDOWS <- list(
  c(35, 64),
  c(95, 126)
)

# ---- Helpers ----

fit_growth_windows <- function(data, windows, time_col = "Row", cases_col) {
  df <- data.frame(
    time  = as.numeric(data[[time_col]]),
    cases = as.numeric(data[[cases_col]])
  )
  df <- df[order(df$time), ]
  df <- df[!is.na(df$time) & !is.na(df$cases), ]

  data_ts <- data.frame(time = df$time, x = df$cases)
  data_windows <- data.frame(
    start = sapply(windows, function(w) w[1] - 1),
    end   = sapply(windows, function(w) w[2])
  )

  fit <- egf(
    model           = egf_model(curve = "logistic"),
    formula_ts      = cbind(time, x) ~ 1,
    formula_windows = cbind(start, end) ~ 1,
    data_ts         = data_ts,
    data_windows    = data_windows
  )
  attr(fit, "data_ts_used")      <- data_ts
  attr(fit, "data_windows_used") <- data_windows
  fit
}

# Find the LOESS-smoothed peak within a window.
peak_in_window <- function(data, window, time_col = "Row", cases_col, span = 0.4) {
  df <- data.frame(
    time  = as.numeric(data[[time_col]]),
    cases = as.numeric(data[[cases_col]])
  )
  df <- df[df$time >= window[1] & df$time <= window[2], ]
  df <- df[!is.na(df$time) & !is.na(df$cases), ]
  if (nrow(df) < 5) return(c(week = NA_real_, cases = NA_real_))

  fit  <- stats::loess(cases ~ time, data = df, span = span, degree = 2)
  yhat <- stats::predict(fit)
  i    <- which.max(yhat)
  c(week = df$time[i], cases = as.numeric(yhat[i]))
}

peak_comparison_table <- function(manual_df, textract_df, windows, cases_col) {
  rows <- list()
  for (i in seq_along(windows)) {
    w  <- windows[[i]]
    pM <- peak_in_window(manual_df,   w, cases_col = cases_col)
    pT <- peak_in_window(textract_df, w, cases_col = cases_col)

    pct_week  <- if (!is.na(pM["week"])  && pM["week"]  != 0) (pT["week"]  - pM["week"])  / pM["week"]  * 100 else NA
    pct_cases <- if (!is.na(pM["cases"]) && pM["cases"] != 0) (pT["cases"] - pM["cases"]) / pM["cases"] * 100 else NA

    rows[[length(rows) + 1]] <- data.frame(
      Window = paste0("Window ", i), Source = "Manual",
      Peak_Week = pM["week"], Peak_Cases = round(pM["cases"]),
      Week_Pct_Diff = NA, Cases_Pct_Diff = NA
    )
    rows[[length(rows) + 1]] <- data.frame(
      Window = paste0("Window ", i), Source = "Textract",
      Peak_Week = pT["week"], Peak_Cases = round(pT["cases"]),
      Week_Pct_Diff = round(pct_week, 2),
      Cases_Pct_Diff = round(pct_cases, 2)
    )
  }
  do.call(rbind, rows)
}

# Extract doubling-time estimates + 95% CIs from an egf fit.
# Returns one row per fitted window.
doubling_times <- function(fit) {
  r_fit <- fitted(fit, top = "log(r)", se = TRUE)
  r_fit <- as.data.frame(r_fit)
  td <- log(2) / exp(r_fit$value)
  td_lo <- log(2) / exp(r_fit$value + 1.96 * r_fit$se)
  td_hi <- log(2) / exp(r_fit$value - 1.96 * r_fit$se)
  data.frame(window = seq_len(nrow(r_fit)), td = td, td_lo = td_lo, td_hi = td_hi)
}

# Custom plot: scatter on log scale, yellow analysis windows, fitted logistic
# curves within each window, and a "Td (lo, hi)" annotation at the top of
# each window. Uses base R so we have full control over the x-axis.
plot_growth <- function(fit, title) {
  ts_data <- attr(fit, "data_ts_used")
  ww      <- attr(fit, "data_windows_used")
  td      <- doubling_times(fit)

  # Scatter on log-y. Keep zeros from blowing up log axis.
  y <- ts_data$x
  y_floor <- max(0.5, min(y[y > 0], na.rm = TRUE) / 2)
  y_plot <- ifelse(y > 0, y, y_floor)

  xr <- range(ts_data$time, na.rm = TRUE)
  yr <- range(y_plot, na.rm = TRUE)

  plot(NA, NA, log = "y",
       xlim = xr, ylim = c(yr[1], yr[2] * 1.6),
       xlab = "Week", ylab = "Interval incidence",
       main = title, las = 1)

  # Yellow shaded analysis windows
  usr_y <- 10 ^ par("usr")[3:4]
  for (i in seq_len(nrow(ww))) {
    rect(ww$start[i], usr_y[1], ww$end[i], usr_y[2],
         col = adjustcolor("khaki1", alpha.f = 0.45), border = NA)
  }

  # Observed points (grey)
  points(ts_data$time, y_plot, pch = 16, col = adjustcolor("grey60", 0.7), cex = 0.7)

  # Fitted logistic curve per window, plus a red dot at fitted peak.
  for (i in seq_len(nrow(ww))) {
    new_times <- seq(ww$start[i], ww$end[i], length.out = 100)
    pred <- tryCatch({
      p <- predict(fit, time = new_times, window = i, log = FALSE)
      as.numeric(p$value)
    }, error = function(e) NULL)

    if (!is.null(pred) && length(pred) == length(new_times)) {
      lines(new_times, pred, col = "darkcyan", lwd = 2)
      i_peak <- which.max(pred)
      points(new_times[i_peak], pred[i_peak], pch = 19, col = "red", cex = 1.1)
    }

    # Doubling-time annotation
    label <- sprintf("%.1f\n(%.1f, %.1f)", td$td[i], td$td_lo[i], td$td_hi[i])
    x_mid <- (ww$start[i] + ww$end[i]) / 2
    text(x_mid, usr_y[2] * 0.6, labels = label, cex = 0.9)
  }

  # Top-right caption (matches the paper's "initial doubling time" header)
  mtext("initial doubling time: value (95% CI)",
        side = 3, line = 0.2, adj = 1, cex = 0.85)
}

process_disease <- function(disease, fig_path, table_path,
                            manual_file, textract_file) {
  manual_df   <- read.csv(manual_file)
  textract_df <- read.csv(textract_file)

  fit_manual   <- fit_growth_windows(manual_df,   WINDOWS, cases_col = disease)
  fit_textract <- fit_growth_windows(textract_df, WINDOWS, cases_col = disease)

  png(fig_path, width = 1400, height = 500, res = 110)
  op <- par(mfrow = c(1, 2), mar = c(4.5, 4.5, 2.5, 1))
  ok <- tryCatch({
    plot_growth(fit_manual,   paste0(disease, " Time Series (Manual)"))
    plot_growth(fit_textract, paste0(disease, " Time Series (Textract)"))
    TRUE
  }, error = function(e) {
    message("Custom plot failed (", conditionMessage(e),
            "), falling back to epigrowthfit::plot.egf().")
    FALSE
  })
  if (!ok) {
    # Reset and use the package's built-in plot method.
    par(op); dev.off()
    png(fig_path, width = 1400, height = 500, res = 110)
    op <- par(mfrow = c(1, 2))
    plot(fit_manual,   main = paste0(disease, " Time Series (Manual)"))
    plot(fit_textract, main = paste0(disease, " Time Series (Textract)"))
  }
  par(op)
  dev.off()
  message("Wrote figure: ", fig_path)

  tbl <- peak_comparison_table(manual_df, textract_df, WINDOWS, cases_col = disease)
  write.csv(tbl, table_path, row.names = FALSE)
  message("Wrote table:  ", table_path)

  invisible(list(fit_manual = fit_manual, fit_textract = fit_textract, table = tbl))
}

# ---- Run for the two diseases in the paper ----

manual_file   <- file.path(ts_dir, "1956-1958_manual_timeseries_chickenpox_measles.csv")
textract_file <- file.path(ts_dir, "1956-1958_textract_timeseries_chickenpox_measles.csv")

# Fig 17 + Table 4: Measles
process_disease(
  disease       = "Measles",
  fig_path      = file.path(fig_dir, "fig17_measles_growth_rates.png"),
  table_path    = file.path(int_dir, "table4_measles_peak_comparison.csv"),
  manual_file   = manual_file,
  textract_file = textract_file
)

# Fig 18 + Table 5: Chickenpox
process_disease(
  disease       = "Chickenpox",
  fig_path      = file.path(fig_dir, "fig18_chickenpox_growth_rates.png"),
  table_path    = file.path(int_dir, "table5_chickenpox_peak_comparison.csv"),
  manual_file   = manual_file,
  textract_file = textract_file
)

message("Done.")
