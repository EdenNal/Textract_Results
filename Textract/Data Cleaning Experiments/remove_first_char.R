clean_cell <- function(x) {
  sapply(x, function(cell) {
    if (is.na(cell)) return(NA)
    cell <- trimws(cell, which = "both", whitespace = "[ \t\r\n]")  # remove surrounding whitespace
    substr(as.character(cell), 2, nchar(as.character(cell)))        # remove first character
  })
}



# Read the input file
input_file <- "table-1.csv"
output_file <- "output.csv"

cat("Reading input file...\n")
df <- read.csv(input_file, stringsAsFactors = FALSE, header = FALSE)

cat("Input loaded:\n")
print(head(df))
df$V1
# Apply the function to every cell
cat("Cleaning each cell...\n")
df_cleaned <- as.data.frame(
  lapply(df, clean_cell),
  
  stringsAsFactors = FALSE
)

cat("First few cleaned rows:\n")
print(head(df_cleaned))
first_blank_row = min(which(apply(df_cleaned, 1, \(x) all(x == "", na.rm = TRUE))))
df_cleaned = df_cleaned[1:(first_blank_row-1),,drop = FALSE]

# Write the result to a new CSV
cat("Writing output file...\n")
write.csv(df_cleaned, output_file, row.names = FALSE)
cat("✅ Done! Output saved to", output_file, "\n")
