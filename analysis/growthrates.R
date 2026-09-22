# Initial growth rates and peak comparisons for Section 5.2.2 of the paper.
#
# Produces:
#   Fig 17  Measles time series with epigrowthfit's doubling-time windows
#           (manual + textract panels)
#   Fig 18  Chickenpox time series with epigrowthfit's doubling-time windows
#           (manual + textract panels)
#   Table 4 Manual-vs-Textract peak comparison for Measles: fit range, peak
#           week/cases, signed delta-week and delta-cases (Textract - Manual),
#           delta-cases %, and doubling time with 95% CI
#   Table 5 Same comparison for Chickenpox
#   growth_rate_summary.csv: one row per disease x source, with the
#           initial growth rate r (per week) and its 95% CI, the doubling
#           time Td and its 95% CI, n observations per fitting window,
#           convergence status, and Delta_r / Delta_Td (Textract - Manual).
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
#   data/analysis_intermediates/growth_rate_summary.csv
#
# Model specification: egf_model(curve = "logistic") with all
# other egf_model() arguments left at their package defaults: family =
# "nbinom" (negative binomial dispersion), day_of_week = FALSE (not
# applicable -- the data are weekly, not daily), excess = FALSE. Every
# top-level parameter (including log(r)) uses the default formula ~1, i.e.
# no fixed or random effect distinguishes window 1 from window 2 -- see the
# doubling_times() comment below for what this implies. Time is indexed in
# weeks (the "Row" column of the input timeseries), so r is a per-week rate.
# CIs are Wald intervals from confint.egf() (profile likelihood / bootstrap
# were not used). Fitting windows (WINDOWS, below) were chosen by visual
# inspection of the incidence curves to bracket the two annual epidemic
# waves; the same two windows are applied to both the Manual and Textract
# series for a given disease (not chosen separately per source).
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

# Number of non-missing weekly observations inside [w[1], w[2]].
n_obs_in_window <- function(data, window, time_col = "Row", cases_col) {
  df <- data.frame(
    time  = as.numeric(data[[time_col]]),
    cases = as.numeric(data[[cases_col]])
  )
  df <- df[df$time >= window[1] & df$time <= window[2], ]
  sum(!is.na(df$time) & !is.na(df$cases))
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

peak_comparison_table <- function(manual_df, textract_df, windows, cases_col,
                                   td_manual = NULL, td_textract = NULL) {
  rows <- list()
  for (i in seq_along(windows)) {
    w  <- windows[[i]]
    pM <- peak_in_window(manual_df,   w, cases_col = cases_col)
    pT <- peak_in_window(textract_df, w, cases_col = cases_col)

    # Sign convention: difference = Textract - Manual, throughout.
    delta_week  <- if (!is.na(pM["week"]))  pT["week"]  - pM["week"]  else NA
    delta_cases <- if (!is.na(pM["cases"])) round(pT["cases"]) - round(pM["cases"]) else NA
    pct_cases   <- if (!is.na(pM["cases"]) && pM["cases"] != 0) (pT["cases"] - pM["cases"]) / pM["cases"] * 100 else NA

    fit_range <- paste0(w[1], "-", w[2])
    n_m <- n_obs_in_window(manual_df,   w, cases_col = cases_col)
    n_t <- n_obs_in_window(textract_df, w, cases_col = cases_col)

    # doubling_times() returns a single shared-r estimate (see its comment
    # above), so the same row is used for every window of a given fit.
    td_m <- if (!is.null(td_manual))   td_manual[1, ]   else NULL
    td_t <- if (!is.null(td_textract)) td_textract[1, ] else NULL

    rows[[length(rows) + 1]] <- data.frame(
      Window = paste0("Window ", i), Fit_Range = fit_range, N_Obs = n_m, Source = "Manual",
      Peak_Week = pM["week"], Peak_Cases = round(pM["cases"]),
      Delta_Peak_Week = NA, Delta_Peak_Cases = NA, Delta_Peak_Cases_Pct = NA,
      r_per_week = if (!is.null(td_m)) signif(td_m$r, 3) else NA,
      r_CI_Lo = if (!is.null(td_m)) signif(td_m$r_lo, 3) else NA,
      r_CI_Hi = if (!is.null(td_m)) signif(td_m$r_hi, 3) else NA,
      Doubling_Time = if (!is.null(td_m)) round(td_m$td, 1) else NA,
      Doubling_Time_CI_Lo = if (!is.null(td_m)) round(td_m$td_lo, 1) else NA,
      Doubling_Time_CI_Hi = if (!is.null(td_m)) round(td_m$td_hi, 1) else NA,
      Converged = if (!is.null(td_m)) td_m$converged else NA
    )
    rows[[length(rows) + 1]] <- data.frame(
      Window = paste0("Window ", i), Fit_Range = fit_range, N_Obs = n_t, Source = "Textract",
      Peak_Week = pT["week"], Peak_Cases = round(pT["cases"]),
      Delta_Peak_Week = delta_week, Delta_Peak_Cases = delta_cases,
      Delta_Peak_Cases_Pct = round(pct_cases, 2),
      r_per_week = if (!is.null(td_t)) signif(td_t$r, 3) else NA,
      r_CI_Lo = if (!is.null(td_t)) signif(td_t$r_lo, 3) else NA,
      r_CI_Hi = if (!is.null(td_t)) signif(td_t$r_hi, 3) else NA,
      Doubling_Time = if (!is.null(td_t)) round(td_t$td, 1) else NA,
      Doubling_Time_CI_Lo = if (!is.null(td_t)) round(td_t$td_lo, 1) else NA,
      Doubling_Time_CI_Hi = if (!is.null(td_t)) round(td_t$td_hi, 1) else NA,
      Converged = if (!is.null(td_t)) td_t$converged else NA
    )
  }
  do.call(rbind, rows)
}

# Extract the doubling-time estimate + 95% CI from an egf fit.
#
# NOTE: the previous implementation called
# fitted(fit, top = "log(r)", se = TRUE) and read $value/$se columns from
# the result. In epigrowthfit 0.15.5, that call returns a bare matrix with
# a single "log(r)" column and NO standard-error column (se = TRUE is not
# honoured by this dispatch path), so r_fit$value / r_fit$se were always
# NULL and exp(NULL) silently produced a non-numeric result. This was never
# surfaced because plot_growth() calls doubling_times() inside a tryCatch
# and falls back to plot.egf() on any error -- the CI annotation on Figs
# 17-18 was therefore never actually computed correctly by the custom plot
# path; every "initial doubling time" run through this fallback silently
# used the (undocumented) epigrowthfit::plot.egf default rendering instead.
#
# Fixed here to use coef()/confint() on the "log(r)" top-level parameter
# directly, which does carry a Wald 95% CI.
#
# formula_windows defines two disjoint FITTING windows (different weeks),
# but formula_parameters is left at its default (~1 for every top-level
# parameter, including log(r)), so the model estimates a single shared
# growth rate r across both windows -- confirmed empirically: fitted(fit,
# top = "log(r)") returns identical values for window_1 and window_2.
# This function therefore returns one doubling-time estimate per fit
# (per disease x source), not one per window; both windows in Figs 17-18
# and both rows of a given disease/source in Tables 4-5 share this value.
doubling_times <- function(fit) {
  cf <- coef(fit, full = FALSE)
  ci <- confint(fit)
  log_r_hat <- unname(cf[1])
  log_r_lo  <- unname(ci[1, 1])
  log_r_hi  <- unname(ci[1, 2])

  r    <- exp(log_r_hat)   # per week (time is indexed in weeks)
  r_lo <- exp(log_r_lo)
  r_hi <- exp(log_r_hi)

  td    <- log(2) / r
  td_lo <- log(2) / r_hi    # larger r -> shorter doubling time, so the CI flips
  td_hi <- log(2) / r_lo

  data.frame(
    window = 1,
    r = r, r_lo = r_lo, r_hi = r_hi,
    td = td, td_lo = td_lo, td_hi = td_hi,
    converged = identical(fit$optimizer_out$convergence, 0L) || identical(fit$optimizer_out$convergence, 0),
    convergence_message = fit$optimizer_out$message
  )
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

    # Doubling-time annotation (single shared-r estimate; same for every window, see doubling_times())
    label <- sprintf("%.1f\n(%.1f, %.1f)", td$td[1], td$td_lo[1], td$td_hi[1])
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

  td_manual   <- doubling_times(fit_manual)
  td_textract <- doubling_times(fit_textract)

  tbl <- peak_comparison_table(manual_df, textract_df, WINDOWS, cases_col = disease,
                                td_manual = td_manual, td_textract = td_textract)
  write.csv(tbl, table_path, row.names = FALSE)
  message("Wrote table:  ", table_path)

  invisible(list(fit_manual = fit_manual, fit_textract = fit_textract, table = tbl,
                 td_manual = td_manual, td_textract = td_textract))
}

# Build the growth-rate summary rows for one disease: one row per
# window x source, with r, Td, their CIs, n_obs, convergence, and the
# Manual-vs-Textract comparison (Delta_r, Delta_Td, CI overlap, whether
# each point estimate falls inside the other source's CI).
growth_rate_summary_rows <- function(disease, data_version, windows,
                                      manual_df, textract_df,
                                      td_manual, td_textract) {
  tm <- td_manual[1, ]
  tt <- td_textract[1, ]

  delta_r  <- tt$r  - tm$r
  delta_td <- tt$td - tm$td

  overlap_r  <- (tm$r_lo  <= tt$r_hi)  && (tt$r_lo  <= tm$r_hi)
  point_in_other_ci <- (tm$r  >= tt$r_lo && tm$r  <= tt$r_hi) &&
                       (tt$r  >= tm$r_lo && tt$r  <= tm$r_hi)

  rows <- list()
  for (i in seq_along(windows)) {
    w <- windows[[i]]
    fit_range <- paste0(w[1], "-", w[2])
    n_m <- n_obs_in_window(manual_df,   w, cases_col = disease)
    n_t <- n_obs_in_window(textract_df, w, cases_col = disease)

    for (src in c("Manual", "Textract")) {
      td <- if (src == "Manual") tm else tt
      n  <- if (src == "Manual") n_m else n_t
      rows[[length(rows) + 1]] <- data.frame(
        Disease = disease, Window = paste0("Window ", i), Fit_Range = fit_range,
        N_Obs = n, Source = src, Data_Version = data_version,
        r_per_week = signif(td$r, 3), r_CI_Lo = signif(td$r_lo, 3), r_CI_Hi = signif(td$r_hi, 3),
        Td_weeks = round(td$td, 2), Td_CI_Lo = round(td$td_lo, 2), Td_CI_Hi = round(td$td_hi, 2),
        Delta_r = if (src == "Textract") signif(delta_r, 3) else NA,
        Delta_Td_weeks = if (src == "Textract") round(delta_td, 2) else NA,
        r_CIs_Overlap = overlap_r,
        Point_Estimate_In_Other_CI = point_in_other_ci,
        Converged = td$converged,
        Convergence_Message = td$convergence_message
      )
    }
  }
  do.call(rbind, rows)
}

# ---- Run for the two diseases in the paper ----

manual_file   <- file.path(ts_dir, "1956-1958_manual_timeseries_chickenpox_measles.csv")
textract_file <- file.path(ts_dir, "1956-1958_textract_timeseries_chickenpox_measles.csv")

# Only one Textract data version is available for Measles/Chickenpox: the
# Stage-2 processed series (comma/whitespace normalization + row-shift
# tolerance, see tab:pipeline in the paper), WITHOUT manual spike correction
# ("hardcoding") -- that correction was applied only to the Meningitis and
# Mumps series (see analysis/cross_correlation.R), not to Measles/Chickenpox.
# A multi-data-version comparison (raw, processed, manually corrected)
# would require a "manually corrected" version of the Measles/Chickenpox
# series, which does not exist; only the processed version is available
# for these two diseases, so that comparison is not run here. See the
# "Known limitations" note in README.md for the full explanation.
DATA_VERSION <- "processed, no manual correction"

manual_df_measles   <- read.csv(manual_file)
textract_df_measles <- read.csv(textract_file)

# Fig 17 + Table 4: Measles
res_measles <- process_disease(
  disease       = "Measles",
  fig_path      = file.path(fig_dir, "fig17_measles_growth_rates.png"),
  table_path    = file.path(int_dir, "table4_measles_peak_comparison.csv"),
  manual_file   = manual_file,
  textract_file = textract_file
)

# Fig 18 + Table 5: Chickenpox
res_chickenpox <- process_disease(
  disease       = "Chickenpox",
  fig_path      = file.path(fig_dir, "fig18_chickenpox_growth_rates.png"),
  table_path    = file.path(int_dir, "table5_chickenpox_peak_comparison.csv"),
  manual_file   = manual_file,
  textract_file = textract_file
)

# ---- Tidy growth-rate summary CSV, one row per disease x window x source ----

grs_measles <- growth_rate_summary_rows(
  "Measles", DATA_VERSION, WINDOWS,
  manual_df_measles, textract_df_measles,
  res_measles$td_manual, res_measles$td_textract
)
grs_chickenpox <- growth_rate_summary_rows(
  "Chickenpox", DATA_VERSION, WINDOWS,
  manual_df_measles, textract_df_measles,
  res_chickenpox$td_manual, res_chickenpox$td_textract
)

growth_rate_summary <- rbind(grs_measles, grs_chickenpox)
growth_rate_summary_path <- file.path(int_dir, "growth_rate_summary.csv")
write.csv(growth_rate_summary, growth_rate_summary_path, row.names = FALSE)
message("Wrote table:  ", growth_rate_summary_path)
print(growth_rate_summary)

message("Done.")
