library(ggplot2)

manual_file   <- read.csv("1956-1958_manual_timeseries_chickenpox_mumps.csv")
textract_file <- read.csv("1956-1958_textract_timeseries_hardcoded.csv")
# Convert to numeric 
x <- as.numeric(textract_file$Chickenpox) 
y <- as.numeric(textract_file$Mumps)

x <- as.numeric(manual_file$Chickenpox) 
y <- as.numeric(manual_file$Mumps)

#  Drop rows with NA in either series (handles internal NAs)
keep <- complete.cases(x, y)
x <- x[keep]
y <- y[keep]


# 1) Compute CCF without plotting
cc <- ccf(x, y,
          lag.max = 12,
          plot = FALSE,
          na.action = na.omit)

# Extract values
lags <- as.vector(cc$lag)
cors <- as.vector(cc$acf)

cc_df <- data.frame(
  Lag = lags,
  Correlation = cors
)

# 2) Significance bounds (approximate)
n <- length(x)
conf <- 2 / sqrt(n)

# 3) Plot
ggplot(cc_df, aes(x = Lag, y = Correlation)) +
  geom_hline(yintercept = 0, color = "black") +
  geom_segment(aes(xend = Lag, yend = 0),
               linewidth = 1.1) +
  geom_hline(yintercept = c(-conf, conf),
             linetype = "dashed",
             color = "red") +
  theme_minimal(base_size = 14) +
  labs(title = "Cross-Correlation: Chickenpox vs Mumps",
       subtitle = "Weekly data (1956–1958), Manual data",
       x = "Lag (weeks)",
       y = "Cross-correlation") +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

