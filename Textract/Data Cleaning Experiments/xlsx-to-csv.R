library(readxl)
library(readr)

output_file <- "changedOutput.csv"

yy = read_csv("output.csv", na = character(), col_types = "c")
xx = readxl::read_xlsx("../cdi_ca_1956_wk_prov_dbs.xlsx", 1L, col_names = FALSE, skip = 4, n_max = nrow(yy), na = character(), col_types = "text")
View(xx)
View(yy)
us = as.matrix(xx)[4:nrow(xx), 3:(ncol(xx) - 1)]
them = as.matrix(yy)[4:nrow(yy), 3:(ncol(xx) - 1)]

mean(us == them)


# Write the result to a new CSV
cat("Writing output file...\n")
write.csv(yy, output_file, row.names = FALSE)
cat("one! Output saved to", output_file, "\n")
