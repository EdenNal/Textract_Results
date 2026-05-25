library(paws)
library(readr)
# library(png)
library(base64enc)
read_bytes <- function(file) {
  con <- file(file, "rb")
  on.exit(close(con), add = TRUE)
  readBin(con, what = "raw", n = file.info(file)$size)
}
bytes <- read_bytes("./2_Columns.png")


png_to_base64 <- function(path) {
  # Read the raw bytes of the PNG
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  
  # Encode to base64
  encoded <- base64enc::base64encode(bytes)
  
  return(encoded)
}
b64 <- png_to_base64("./2_Columns.png")

out <- c("TABLES")
x<-paws::textract()
x<-x$analyze_document(Document=list(Bytes=bytes), FeatureTypes=out)
x<-x$Blocks

`%||%` <- function(x, y) if (is.null(x)) y else x


get_table_csv_results <- function(imageInput){
  cat("get_table_csv_results function reached")
  
  b64<-png_to_base64(imageInput)
  textract <- paws::textract()
  resp <- textract$analyze_document(Document=list(Bytes=bytes), FeatureTypes=out)
  blocks <- resp$Blocks %||% list()
  table_blocks <- list()
  blocks_map <- new.env(parent = emptyenv())
  
  for (i in seq_along(blocks)){
    b <- blocks[[i]]
    if (is.null(b$Id)) next
    if (identical(b$BlockType, "TABLE")){
      table_blocks[[length(table_blocks)+1]] <- b
    }
  }
  
  csv <- character(0)
  for (i in seq_along(table_blocks)){
    csv <- c(csv, generate_table_csv(table_blocks[[i]], as.list.environment(blocks_map), i), "")
  }
  paste(csv, collapse="\n")
}


get_rows_columns_map <- function(table_result, blocks_map){
  rows <- list()
  
  if (is.null(table_results$Relationships)==FALSE){
    for (rel in table_results$Relationships){
      if (!identical(rel$Type, "CHILD")) next
      for (child_id in rel$Ids) {
        cell <- blocks_map[[child_id]]
        if (is.null(cell) || !identical(cell$BlockType, "CELL")) next
        
        row_index <- as.character(cell$RowIndex %||% NA)
        col_index <- as.character(cell$ColumnIndex %||% NA)
        
        if (is.null(rows[[row_index]])) rows[[row_index]] <- list()
        rows[[row_index]][[col_index]] <- get_text(cell, blocks_map)
      }
      
      }
  }
  list(rows=rows)
  }





generate_table_csv <- function(table_result, blocks_map, table_index){
  cat("generate_table_csv function reached")
  rc <- get_rows_columns_map(table_result, blocks_map)
  rows<-rc$rows
  row_keys <- sort(as.integer(names(rows)))
  out <- character(0)
  out <- c(out, sprintf("Table: %s\n", paste0("Table_", table_index)))
  out <- c(out,"")
  for (rk in row_keys){
    cols <- rows[[as.character(rk)]]
    col_keys<-sort(as.integer(name(cols)))
    line_vals <- vapply(col_keys, function(ck) twimws(cols[[as.character(ck)]]), "", USE.NAMES = FALSE)
    out <- c(out, paste0(pase(line_vals, collapse = ","),","))
  }
}

main <- function(file_name, output_file = "output.csv"){
  cat("Main function reached")
  
  csv <- get_table_csv_results(file_name)
  writeLines(csv, con = output_file, useBytes = TRUE)
  cat("csv output file is... : ", output_file)
}
