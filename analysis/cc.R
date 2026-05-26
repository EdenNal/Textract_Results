library(ggplot2)

lag_max <- 12

# -------------------------
# Helper: compute CCF safely for any two columns in a CSV
# -------------------------
compute_ccf_df <- function(csv_file, x_col, y_col, lag_max = 12) {
  
  # Read CSV (DON'T use row.names=1 unless you truly need it)
  df <- read.csv(csv_file, check.names = FALSE)
  
  # If your file has a first column like Row or Week index, and you don't need it,
  # this will ignore it automatically by selecting columns by name below.
  
  # Hard stop if columns are missing (prevents length mismatch / NULL vectors)
  if (!(x_col %in% names(df))) {
    stop(sprintf("Missing column '%s' in %s. Columns are: %s",
                 x_col, csv_file, paste(names(df), collapse = ", ")))
  }
  if (!(y_col %in% names(df))) {
    stop(sprintf("Missing column '%s' in %s. Columns are: %s",
                 y_col, csv_file, paste(names(df), collapse = ", ")))
  }
  
  x <- as.numeric(df[[x_col]])
  y <- as.numeric(df[[y_col]])
  
  # Guarantee same length BEFORE complete.cases
  if (length(x) != length(y)) {
    stop(sprintf("Length mismatch in %s: %s has %d rows, %s has %d rows",
                 csv_file, x_col, length(x), y_col, length(y)))
  }
  
  # Drop rows where either x or y is NA (keeps x/y aligned)
  keep <- complete.cases(x, y)
  x <- x[keep]
  y <- y[keep]
  
  # Scale (scale() returns a matrix -> coerce to numeric)
  x <- as.numeric(scale(x))
  y <- as.numeric(scale(y))
  
  # CCF
  cc <- ccf(x, y, lag.max = lag_max, plot = FALSE)
  
  data.frame(
    Lag = as.vector(cc$lag),
    Cor = as.vector(cc$acf)
  )
}

# -------------------------
# 1) Compute both CCFs
# -------------------------
manual_file   <- "1956-1958_manual_timeseries_chickenpox_mumps.csv"
textract_file <- "1956-1958_textract_timeseries_hardcoded.csv"

# Set the pair you want here:
x_col <- "Chickenpox"
y_col <- "Mumps"   

manual_df   <- compute_ccf_df(manual_file,   x_col, y_col, lag_max)
textract_df <- compute_ccf_df(textract_file, x_col, y_col, lag_max)

names(manual_df)[2]   <- "Manual"
names(textract_df)[2] <- "Textract"

# -------------------------
# 2) Merge by lag + compute differences
# -------------------------
diff_df <- merge(manual_df, textract_df, by = "Lag", all = TRUE)
diff_df$Difference <- diff_df$Manual - diff_df$Textract

print(diff_df)

# Best-lag comparison (by absolute correlation)
best_manual   <- diff_df$Lag[which.max(abs(diff_df$Manual))]
best_textract <- diff_df$Lag[which.max(abs(diff_df$Textract))]

cat("Manual best lag:", best_manual, "\n")
cat("Textract best lag:", best_textract, "\n")
cat("Best-lag difference (Manual - Textract):", best_manual - best_textract, "\n")

# -------------------------
# 3) Plot: difference (Manual - Textract) by lag
# -------------------------
ggplot(diff_df, aes(x = Lag, y = Difference)) +
  geom_hline(yintercept = 0) +
  geom_segment(aes(xend = Lag, yend = 0), linewidth = 1.2) +
  theme_minimal(base_size = 14) +
  labs(
    title = "CCF Difference by Lag",
    subtitle = paste0("Manual − Textract (", x_col, " vs ", y_col, ")"),
    x = "Lag (weeks)",
    y = "Correlation difference"
  )

# -------------------------
# 4) OPTIONAL: Overlay plot
# -------------------------
overlay_df <- rbind(
  data.frame(Lag = diff_df$Lag, Cor = diff_df$Manual,   Source = "Manual"),
  data.frame(Lag = diff_df$Lag, Cor = diff_df$Textract, Source = "Textract")
)

ggplot(overlay_df, aes(x = Lag, y = Cor, group = Source)) +
  geom_hline(yintercept = 0) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  theme_minimal(base_size = 14) +
  labs(
    title = "CCF Overlay",
    subtitle = paste0("Manual vs Textract (", x_col, " vs ", y_col, ")"),
    x = "Lag (weeks)",
    y = "Cross-correlation"
  )