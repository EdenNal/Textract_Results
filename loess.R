# Fit LOESS and find peak (max) for a chosen disease column.
# Expects a data.frame with columns: week_index and disease columns like "Measles", "Chickenpox".
# Returns peak week, peak height, and the fitted curve (useful for plotting).

loess_peak <- function(df,
                       disease = "Measles",
                       span = 0.2,
                       degree = 2,
                       family = c("gaussian", "symmetric")) {
  family <- match.arg(family)
  
  # Basic checks
  if (!("week_index" %in% names(df))) stop("df must have a 'week_index' column.")
  if (!(disease %in% names(df))) stop(sprintf("Column '%s' not found in df.", disease))
  
  x <- as.numeric(df$week_index)
  y <- as.numeric(df[[disease]])
  
  keep <- is.finite(x) & is.finite(y)
  x <- x[keep]
  y <- y[keep]
  
  if (length(x) < 5) stop("Not enough non-missing points to fit LOESS (need at least ~5).")
  
  # Fit LOESS: y ~ x
  fit <- stats::loess(y ~ x, span = span, degree = degree, family = family)
  
  # Predict smoothed values at observed weeks (or you could use a denser grid)
  yhat <- stats::predict(fit, newdata = data.frame(x = x))
  
  # Peak = max of smoothed curve
  i_peak <- which.max(yhat)
  peak_week  <- x[i_peak]
  peak_height <- yhat[i_peak]
  
  # Return a tidy result + curve for plotting
  list(
    disease = disease,
    peak_week_index = peak_week,
    peak_height = as.numeric(peak_height),
    fit = fit,
    curve = data.frame(week_index = x, y = y, yhat = as.numeric(yhat))
  )
}

df <- read.csv("measles_chickenpox/1956-1958_manual_timeseries_chickenpox_measles.csv") 
df_t <- read.csv("measles_chickenpox/1956-1958_textract_timeseries_chickenpox_measles.csv")
head(df)
head(df_t)
res <- loess_peak(df, disease="Measles", span=0.25)

res$peak_week_index
res$peak_height
plot(res$curve$week_index, res$curve$y, pch=16)
lines(res$curve$week_index, res$curve$yhat, lwd=2)
