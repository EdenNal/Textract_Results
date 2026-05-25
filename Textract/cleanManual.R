library(readr)
library(readxl)
library(tools)

###### This file takes in a file (line 20) of manually entered data, 
###### and produces a clean file without whitespace, headers, etc.


is_numeric_string <- function(x) {
  suppressWarnings(!is.na(as.numeric(x)))
}

# -------- I/O --------
input_file  <- "../cdi_ca_1956_wk_prov_dbs.xlsx"

output_file <- sprintf(
    "%s_cleaned.csv"
  , tools::file_path_sans_ext(basename(input_file))
)



if (!file.exists(input_file)) stop("Input does not exist: ", input_file)

file_ext <- tolower(tools::file_ext(input_file))

read_fn <- if (file_ext == "xlsx") {
  function(path) {
    x <- read_xlsx(path, na = character(), col_types = "text", col_names = FALSE)
    x[is.na(x)] <- "IS_NA"
    x[x == "NA"] <- "IS_NA"
    x
  }
} else if (file_ext == "csv") {
  function(path) {
    x <- read_csv(path, na = character(), show_col_types = FALSE,
                  col_types = cols(.default = col_character()))
    x[is.na(x)] <- "IS_NA"
    x[x == "NA"] <- "IS_NA"
    x
  }
} else {
  stop("Unknown extension: ", file_ext)
}

cat("Reading input file...\n")
df_cleaned <- read_fn(input_file)
cat("Input loaded:\n"); print(head(df))



# -------- Trim at first completely blank row (if present) --------
blank_rows <- apply(df_cleaned, 1, function(r) all(is.na(r) | r == ""))
if (any(blank_rows)) {
  first_blank_row <- which(blank_rows)[1]
  if (first_blank_row > 1) {
    df_cleaned <- df_cleaned[1:(first_blank_row - 1), , drop = FALSE]
  } else {
    # first row blank -> drop it
    df_cleaned <- df_cleaned[-1, , drop = FALSE]
  }
}

# -------- Drop header rows  --------
start_row <- NA_integer_
for (i in seq_len(nrow(df_cleaned))) {
  row_vals <- unlist(df_cleaned[i, ], use.names = FALSE)
  if (length(row_vals) == 0) next
  numeric_count <- sum(sapply(row_vals, is_numeric_string))
  if ((numeric_count / length(row_vals)) >= 0.5) {
    start_row <- i
    break
  }
}

if (is.na(start_row)) {
  warning("No row with >=50% numeric values found; keeping all rows (no header drop).")
  cleaned_data <- df_cleaned
} else {
  cleaned_data <- df_cleaned[start_row:nrow(df_cleaned), , drop = FALSE]
}

# -------- Write CSV (no headers) --------
cat("Writing output file...\n")
write_csv(cleaned_data, output_file, col_names = FALSE)
cat("Cleaned manual data saved to:", output_file, "\n")

