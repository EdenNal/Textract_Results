# Distribution of weekly Meningitis cases (Section 5.3 of the paper).
#
# Produces Fig 22: a two-panel boxplot of weekly Meningitis case counts
# from the raw (pre-hardcoding) Textract series, on linear and log scales.
# The figure makes the outlier OCR-error spikes visible.
#
# Input:
#   data/timeseries/meningitis_measles/1956-1958_textract_timeseries_meningitis_measles.csv
#
# Output:
#   figures/fig22_meningitis_boxplots.png
#
# Usage (from repo root):
#   Rscript analysis/boxplots.R

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

input_file <- file.path(repo_root, "data", "timeseries", "meningitis_measles",
                        "1956-1958_textract_timeseries_meningitis_measles.csv")
fig_dir    <- file.path(repo_root, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# ---- Build the figure ----
df <- read.csv(input_file)

linear_panel <- ggplot(df, aes(x = "", y = Meningitis)) +
  geom_boxplot(fill = "steelblue", width = 0.3) +
  labs(title = "Distribution of Weekly Meningitis Cases",
       x = NULL, y = "Number of Cases") +
  theme_classic(base_size = 13)

log_panel <- ggplot(df[df$Meningitis > 0, ], aes(x = "", y = Meningitis)) +
  geom_boxplot(fill = "steelblue", width = 0.7) +
  scale_y_log10() +
  labs(title = "Distribution of Weekly Meningitis Cases (Log Scale)",
       x = NULL, y = "Number of Cases (log10)") +
  theme_classic(base_size = 13)

# Combine the two panels side-by-side; fall back to individual files
# if neither patchwork nor gridExtra is available.
fig_path <- file.path(fig_dir, "fig22_meningitis_boxplots.png")
saved <- FALSE
if (requireNamespace("patchwork", quietly = TRUE)) {
  combined <- linear_panel + log_panel
  ggsave(fig_path, combined, width = 15, height = 5, dpi = 150)
  saved <- TRUE
} else if (requireNamespace("gridExtra", quietly = TRUE)) {
  g <- gridExtra::arrangeGrob(linear_panel, log_panel, ncol = 2)
  ggsave(fig_path, g, width = 15, height = 5, dpi = 150)
  saved <- TRUE
}
if (!saved) {
  ggsave(sub("\\.png$", "_linear.png", fig_path), linear_panel,
         width = 5, height = 5, dpi = 150)
  ggsave(sub("\\.png$", "_log.png",    fig_path), log_panel,
         width = 5, height = 5, dpi = 150)
  message("Note: install 'patchwork' or 'gridExtra' for a combined two-panel figure.")
}

message("Wrote figure: ", fig_path)
