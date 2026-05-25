# install.packages("paws")  # uncomment if needed

library(paws)

# ---------- helpers ----------
get_text <- function(result, blocks_map) {
  txt <- ""
  if (!is.null(result$Relationships)) {
    for (rel in result$Relationships) {
      if (!identical(rel$Type, "CHILD")) next
      for (child_id in rel$Ids) {
        word <- blocks_map[[child_id]]
        if (is.null(word)) next
        if (identical(word$BlockType, "WORD")) {
          w <- word$Text %||% ""
          # quote numbers containing commas, e.g., "1,234"
          is_comma_num <- grepl(",", w, fixed = TRUE) &&
            !is.na(suppressWarnings(as.numeric(gsub(",", "", w))))
          if (is_comma_num) {
            txt <- paste0(txt, '"', w, '" ')
          } else {
            txt <- paste0(txt, w, " ")
          }
        } else if (identical(word$BlockType, "SELECTION_ELEMENT")) {
          if (identical(word$SelectionStatus, "SELECTED")) {
            txt <- paste0(txt, "X ")
          }
        }
      }
    }
  }
  txt
}

`%||%` <- function(x, y) if (is.null(x)) y else x

get_rows_columns_map <- function(table_result, blocks_map) {
  rows <- list()
  scores <- character(0)
  
  if (!is.null(table_result$Relationships)) {
    for (rel in table_result$Relationships) {
      if (!identical(rel$Type, "CHILD")) next
      for (child_id in rel$Ids) {
        cell <- blocks_map[[child_id]]
        if (is.null(cell) || !identical(cell$BlockType, "CELL")) next
        
        row_index <- as.character(cell$RowIndex %||% NA)
        col_index <- as.character(cell$ColumnIndex %||% NA)
        
        if (is.null(rows[[row_index]])) rows[[row_index]] <- list()
        
        scores <- c(scores, as.character(cell$Confidence %||% ""))
        
        rows[[row_index]][[col_index]] <- get_text(cell, blocks_map)
      }
    }
  }
  
  list(rows = rows, scores = scores)
}

generate_table_csv <- function(table_result, blocks_map, table_index) {
  rc <- get_rows_columns_map(table_result, blocks_map)
  rows <- rc$rows
  scores <- rc$scores
  
  # sort rows/cols numerically by their indices
  row_keys <- sort(as.integer(names(rows)))
  # compute max column count for wrapping confidence scores
  n_cols_max <- 0
  for (rk in row_keys) {
    cols <- rows[[as.character(rk)]]
    n_cols_max <- max(n_cols_max, length(cols))
  }
  
  out <- character(0)
  out <- c(out, sprintf("Table: %s\n", paste0("Table_", table_index)))
  out <- c(out, "")
  
  for (rk in row_keys) {
    cols <- rows[[as.character(rk)]]
    col_keys <- sort(as.integer(names(cols)))
    line_vals <- vapply(col_keys, function(ck) trimws(cols[[as.character(ck)]]), "", USE.NAMES = FALSE)
    # trailing comma like original
    out <- c(out, paste0(paste(line_vals, collapse = ","), ","))
  }
  
  out <- c(out, "", " Confidence Scores % (Table Cell) ")
  if (length(scores) > 0 && n_cols_max > 0) {
    cnt <- 0
    line <- ""
    for (s in scores) {
      line <- paste0(line, s, ",")
      cnt <- cnt + 1
      if (cnt == n_cols_max) {
        out <- c(out, line)
        line <- ""
        cnt <- 0
      }
    }
    if (nzchar(line)) out <- c(out, line)
  }
  
  out <- c(out, "", "")
  paste(out, collapse = "\n")
}

get_table_csv_results <- function(file_name, region = Sys.getenv("AWS_REGION", unset = NA)) {
  # read image bytes
  bytes <- readBin(file_name, what = "raw", n = file.info(file_name)$size)
  cat("Image loaded", file_name, "\n")
  
  # textract client (use default env/profile; region from env unless provided)
  if (!is.na(region) && nzchar(region)) {
    Sys.setenv(AWS_REGION = region)
  }
  textract <- paws.machine.learning$textract()
  
  resp <- textract$analyze_document(
    Document = list(Bytes = bytes),
    FeatureTypes = list("TABLES")
  )
  
  blocks <- resp$Blocks %||% list()
  # map blocks by Id
  blocks_map <- new.env(parent = emptyenv())
  table_blocks <- list()
  
  for (i in seq_along(blocks)) {
    blk <- blocks[[i]]
    if (is.null(blk$Id)) next
    blocks_map[[blk$Id]] <- blk
    if (identical(blk$BlockType, "TABLE")) {
      table_blocks[[length(table_blocks) + 1]] <- blk
    }
  }
  
  if (length(table_blocks) == 0) return("<b> NO Table FOUND </b>")
  
  csv <- character(0)
  for (i in seq_along(table_blocks)) {
    csv <- c(csv, generate_table_csv(table_blocks[[i]], as.list.environment(blocks_map), i), "")
  }
  paste(csv, collapse = "\n")
}

main <- function(file_name, output_file = "output.csv", region = NULL) {
  csv <- get_table_csv_results(file_name, region = region %||% Sys.getenv("AWS_REGION", unset = NA))
  writeLines(csv, con = output_file, useBytes = TRUE)
  cat("CSV OUTPUT FILE:", output_file, "\n")
}


