library(epigrowthfit)
library(ggplot2)
library(dplyr)

fit_growth_windows <- function(data,
                               windows,
                               time_col = "Row",
                               cases_col = "Measles") {
  
  df <- data.frame(
    time = as.numeric(data[[time_col]]),
    cases = as.numeric(data[[cases_col]])
  )
  
  df <- df[order(df$time), ]
  df <- df[!is.na(df$time) & !is.na(df$cases), ]
  
  results <- list()
  
  for(i in seq_along(windows)){
    
    start_i <- windows[[i]][1]
    end_i   <- windows[[i]][2]
    
    wave <- df[df$time >= start_i & df$time <= end_i, ]
    wave <- wave[!is.na(wave$cases), ]
    
    if(nrow(wave) < 2) {
      warning(paste("Skipping window", i, "- not enough rows"))
      next
    }
    
    data_ts <- data.frame(
      time = wave$time,
      x = wave$cases
    )
    
    data_windows <- data.frame(
      start = start_i - 1,
      end   = end_i
    )
    
    fit <- egf(
      model = egf_model(curve = "logistic"),
      formula_ts = cbind(time, x) ~ 1,
      formula_windows = cbind(start, end) ~ 1,
      data_ts = data_ts,
      data_windows = data_windows
    )
    
    r_fit <- fitted(fit, top = "log(r)", class = TRUE, se = TRUE)
    
    log_r <- r_fit$value[1]
    se    <- r_fit$se[1]
    
    r  <- exp(log_r)
    rL <- exp(log_r - 1.96 * se)
    rU <- exp(log_r + 1.96 * se)
    
    results[[i]] <- data.frame(
      window = i,
      start = start_i,
      end = end_i,
      r = r,
      lower = rL,
      upper = rU
    )
  }
  
  results <- bind_rows(results)
  
  results$mid <- (results$start + results$end)/2
  
  results$label <- paste0(
    "r = ", round(results$r,3),
    "\n95% CI [", round(results$lower,3),
    ", ", round(results$upper,3), "]"
  )
  
  p <- ggplot(df, aes(time, cases)) +
    geom_line(color = "black") +
    geom_point(size = 1.2) +
    geom_rect(
      data = results,
      inherit.aes = FALSE,
      aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
      fill = "skyblue",
      alpha = 0.2
    ) +
    geom_text(
      data = results,
      inherit.aes = FALSE,
      aes(x = mid, y = max(df$cases, na.rm = TRUE) * 0.95, label = label),
      size = 4
    ) +
    labs(
      title = "Measles Growth Rates (Textract)",
      x = "Week",
      y = "Cases"
    ) +
    theme_minimal()
  
  print(p)
  
  return(results)
}

df <- read.csv("measles_chickenpox/1956-1958_manual_timeseries_chickenpox_measles.csv")
df_t <- read.csv("measles_chickenpox/1956-1958_textract_timeseries_chickenpox_measles.csv")

windows <- list(
  c(35, 64),
  c(95, 126)
)

df_check <- data.frame(
  Row = as.numeric(df$Row),
  Measles = as.numeric(df$Measles)
)

dft_check <- data.frame(
  Row = as.numeric(df_t$Row),
  Measles = as.numeric(df_t$Measles)
)

df_check[is.na(df_check$Measles) | is.na(df_check$Row), ]
dft_check[is.na(dft_check$Measles) | is.na(dft_check$Row), ]

results_t <- fit_growth_windows(df_t, windows, time_col = "Row", cases_col = "Measles")
results   <- fit_growth_windows(df, windows, time_col = "Row", cases_col = "Measles")

print(results_t)
print(results)


