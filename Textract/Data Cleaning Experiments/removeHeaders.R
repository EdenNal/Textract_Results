library(readxl)
library(readr)

# === CONFIG ===
#input_file <- "../cdi_ca_1956_wk_prov_dbs.xlsx"
input_file <- "output.csv"
output_file = (input_file 
  |> basename() 
  |> tools::file_path_sans_ext()
  |> sprintf(fmt = "%s_NoHeaders.csv")
)

# === Load Excel as character data (no header) ===
#df <- read_csv(input_file, col_names = FALSE, col_types = "text")

if (!file.exists(input_file)) stop("Input doesn't exist")

file_ext = tools::file_ext(input_file)
read_fn = if (file_ext == "xlsx") {
  function(path) {
    x = read_xlsx(path, na = character(), col_types = "text", col_names = FALSE) 
    x[is.na(x)] <- ""
    x[x == "NA"] <- ""
    return(x)
  }
} else if (file_ext == "csv") {
  function(path) {
    x = read_csv(path, na = character(), col_types = list(.default = "c"))
    x[is.na(x)] <- ""
    x[x == "NA"] <- ""
    return(x)
  }
} else {
  stop("Unknown extension")
}
df <- read_fn(input_file)


# === Function to check if a string is numeric ===
is_numeric_string <- function(x) {
  suppressWarnings(!is.na(as.numeric(x)))
}

# === Detect first row where more than 50% of values are numeric ===
start_row <- NA
for (i in seq_len(nrow(df))) {
  row_vals <- unlist(df[i, ])
  if (length(row_vals) == 0) next
  
  numeric_count <- sum(sapply(row_vals, is_numeric_string))
  if (numeric_count / length(row_vals) >= 0.5) {
    start_row <- i
    break
  }
}

# === Check if numeric start row was found ===
if (is.na(start_row)) {
  stop("No row with >=50% numeric values found.")
}

# === Extract data starting from that row ===
cleaned_data <- df[start_row:nrow(df), ]

# === Write to file without header row ===
write_csv(cleaned_data, output_file, col_names = FALSE, quote = "all", )
cat("leaned data saved to:", output_file, "\n")
