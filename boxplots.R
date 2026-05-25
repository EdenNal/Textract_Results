data <- read.csv("meningitis_measles/1956-1958_textract_timeseries_meningitis_measles.csv")

boxplot(data$Meningitis,
        main = "Distribution of Weekly Meningitis Cases",
        ylab = "Meningitis Cases",
        col = "lightblue")

library(ggplot2)


ggplot(data, aes(x = "", y = Meningitis)) +
  geom_boxplot(fill = "steelblue", width = 0.3) +
  labs(title = "Distribution of Weekly Meningitis Cases",
       x = "",
       y = "Number of Cases") +
  theme_classic()
s <- summary(data$Meningitis)

ggplot(data, aes(x = "", y = Meningitis)) +
  geom_boxplot(fill = "lightblue", width = 0.3) +
  geom_text(aes(x = 1.2, y = s[1], label = paste("Min =", round(s[1],2)))) +
  geom_text(aes(x = 1.2, y = s[2], label = paste("Q1 =", round(s[2],2)))) +
  geom_text(aes(x = 1.2, y = s[3], label = paste("Median =", round(s[3],2)))) +
  geom_text(aes(x = 1.2, y = s[5], label = paste("Q3 =", round(s[5],2)))) +
  geom_text(aes(x = 1.2, y = s[6], label = paste("Max =", round(s[6],2)))) +
  labs(title = "Boxplot of Weekly Meningitis Cases",
       x = "",
       y = "Number of Cases") +
  theme_classic()


df <- read.csv("meningitis_measles/1956-1958_textract_timeseries_meningitis_measles.csv")

s <- summary(data$Meningitis[data$Meningitis > 0])

library(ggplot2)

ggplot(df[df$Meningitis > 0, ], aes(x = "", y = Meningitis)) +
  geom_boxplot(fill = "steelblue", width = 0.3) +
  scale_y_log10() +
  labs(title = "Distribution of Weekly Meningitis Cases (Log Scale)",
       x = "",
       y = "Number of Cases (log10)") +
  theme_classic()


ggplot(data, aes(x = Row, y = Meningitis)) +
  geom_line(size = 1) +
  coord_cartesian(xlim = c(0, 160)) +
  scale_x_continuous(breaks = seq(0, 160, 15)) +
  labs(
    x = "Each Week's Reported Meningitis Cases from 1956-1958",
    y = "Meningitis Cases"
  ) +
  theme_minimal()
