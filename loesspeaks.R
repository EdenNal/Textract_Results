# Needs: install.packages("ggplot2")
library(ggplot2)

# Original helper (peak + curve) + a ggplot wrapper
plot_loess_with_peak <- function(df,
                                 disease = "Measles",
                                 span = 0.2,
                                 degree = 2,
                                 family = c("gaussian", "symmetric")) {
  
  family <- match.arg(family)
  
  if (!("week_index" %in% names(df))) stop("df must have a 'week_index' column.")
  if (!(disease %in% names(df))) stop(sprintf("Column '%s' not found in df.", disease))
  
  x <- as.numeric(df$week_index)
  y <- as.numeric(df[[disease]])
  keep <- is.finite(x) & is.finite(y)
  
  x <- x[keep]
  y <- y[keep]
  if (length(x) < 5) stop("Not enough non-missing points to fit LOESS (need at least ~5).")
  
  fit <- stats::loess(y ~ x, span = span, degree = degree, family = family)
  yhat <- stats::predict(fit, newdata = data.frame(x = x))
  
  curve <- data.frame(week_index = x, y = y, yhat = as.numeric(yhat))
  
  i_peak <- which.max(curve$yhat)
  peak <- data.frame(
    week_index = curve$week_index[i_peak],
    peak_height = curve$yhat[i_peak]
  )
  
  p <- ggplot(curve, aes(x = week_index)) +
    geom_point(aes(y = y), alpha = 0.6, color="royalblue2") +
    geom_line(aes(y = yhat), linewidth = 1.1) +
    geom_point(data = peak, aes(y = peak_height), size = 3, color="red") +
    geom_vline(data = peak, aes(xintercept = week_index), linetype = "dashed", alpha = 0.6) +
    labs(
      title = paste0(disease, ": weekly incidence with LOESS (Textract)"),
      subtitle = paste0("Peak at week ", peak$week_index, " (smoothed height ≈ ", round(peak$peak_height, 1), ")"),
      x = "Week index",
      y = "Cases"
    ) +
    theme_minimal(base_size = 12)
  
  list(plot = p, peak = peak, fit = fit, curve = curve)
}

# Example:
out <- plot_loess_with_peak(df, disease="Chickenpox", span=0.25)
out$plot
out$peak

out <- plot_loess_with_peak(df_t, disease="Chickenpox", span=0.25)
out$plot
out$peak
