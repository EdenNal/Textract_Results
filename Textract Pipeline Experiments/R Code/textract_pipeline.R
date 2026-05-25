#install.packages(c("paws", "optparse", "jsonlite", "data.table", "fs", "readr"))
#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(paws)
  library(jsonlite)
  library(data.table)
  library(fs)
  library(readr)
})


IMG_EXTS <- c(".png", ".jpg", ".jpeg", ".tif", ".tiff")

find_images <- function(path) {
  p <- fs::path_abs(path)
  if (fs::dir_exists(p)) {
    files <- fs::dir_ls(p, recurse = TRUE, type = "file", glob = "*")
    files <- files[tolower(fs::path_ext(files)) %in% sub("^\\.", "", IMG_EXTS)]
    files <- files[order(files)]
    if (length(files) == 0) stop("No images found in folder.")
    return(files)
  } else if (fs::file_exists(p)) {
    ext <- tolower(fs::path_ext(p))
    if (paste0(".", ext) %in% IMG_EXTS) return(p)
    stop("Unsupported file extension: ", ext)
  } else {
    stop("Path not found: ", path)
  }
}

ensure_dirs <- function(out_dir) {
  raw_dir <- fs::path(out_dir, "raw")
  txt_dir <- fs::path(out_dir, "text")
  fs::dir_create(raw_dir, recurse = TRUE)
  fs::dir_create(txt_dir, recurse = TRUE)
  list(raw = raw_dir, txt = txt_dir)
}

read_bytes <- function(file) {
  con <- file(file, "rb")
  on.exit(close(con), add = TRUE)
  readBin(con, what = "raw", n = file.info(file)$size)
}

parse_lines <- function(resp) {
  blocks <- resp$Blocks
  if (is.null(blocks)) return(data.table(text = character(), confidence = numeric()))
  idx <- vapply(blocks, function(b) identical(b$BlockType, "LINE"), logical(1))
  lines <- blocks[idx]
  if (!length(lines)) return(data.table(text = character(), confidence = numeric()))
  data.table(
    text = vapply(lines, function(b) ifelse(is.null(b$Text), "", b$Text), character(1)),
    confidence = vapply(lines, function(b) ifelse(is.null(b$Confidence), NA_real_, as.numeric(b$Confidence)), numeric(1))
  )
}

detect_document_text_bytes <- function(client, file_path) {
  bytes <- read_bytes(file_path)
  # paws expects a raw vector in Document$Bytes
  client$detect_document_text(Document = list(Bytes = bytes))
  #client$analyze_document(Document = list(Bytes = bytes))
}

test <-paws::textract()

process_one <- function(client, out_dir, file_path) {
  dirs <- ensure_dirs(out_dir)
  base <- fs::path_ext_remove(fs::path_file(file_path))
  
  # Call Textract
  resp <- tryCatch(
    detect_document_text_bytes(client, file_path),
    error = function(e) {
      message(sprintf("[error] %s: %s", file_path, e$message))
      return(NULL)
    }
  )
  if (is.null(resp)) return(NULL)
  
  # Save raw JSON
  raw_path <- fs::path(dirs$raw, paste0(base, ".json"))
  message(raw_path)
  writeLines(jsonlite::toJSON(resp, auto_unbox = TRUE, pretty = TRUE, null = "null"), raw_path, useBytes = TRUE)
  
  # Extract lines
  dt <- parse_lines(resp)
  if (nrow(dt)) {
    # Save TXT
    txt_path <- fs::path(dirs$txt, paste0(base, ".txt"))
    readr::write_lines(dt$text, txt_path)
  }
  if (!nrow(dt)) dt <- data.table(text = character(), confidence = numeric())
  dt[, filename := fs::path_file(file_path)]
  dt[, line_num := seq_len(.N)]
  setcolorder(dt, c("filename", "line_num", "text", "confidence"))
  dt
}

main <- function() {
  option_list <- list(
    make_option(c("-o", "--out"), type = "character", default = "./out", help = "Output directory"),
    make_option(c("-r", "--region"), type = "character", default = NULL, help = "AWS region (e.g., us-east-1)"),
    make_option(c("-p", "--profile"), type = "character", default = NULL, help = "AWS shared credentials profile name")
  )
  parser <- OptionParser(usage = "%prog <image_or_folder> [options]", option_list = option_list)
  args <- parse_args(parser, positional_arguments = TRUE)
  
  if (length(args$args) != 1) {
    print_help(parser)
    quit(status = 1)
  }
  target_path <- args$args[1]
  out_dir <- args$options$out
  region <- args$options$region
  profile <- args$options$profile
  
  # paws uses env/config/role chain; we optionally set a profile via env var
  if (!is.null(profile) && nzchar(profile)) {
    Sys.setenv(AWS_PROFILE = profile)
  }
  # paws picks up region from env; set if provided
  if (!is.null(region) && nzchar(region)) {
    Sys.setenv(AWS_DEFAULT_REGION = region, AWS_REGION = region)
  }
  
  files <- find_images(target_path)
  fs::dir_create(out_dir, recurse = TRUE)
  
  textract <- paws::textract()
  
  rows <- vector("list", length(files))
  for (i in seq_along(files)) {
    fp <- files[[i]]
    message(sprintf("[%d/%d] %s", i, length(files), fp))
    dt <- process_one(textract, out_dir, fp)
    rows[[i]] <- dt
  }
  
  all <- data.table::rbindlist(rows, fill = TRUE)
  if (nrow(all)) {
    out_csv <- fs::path(out_dir, "all_lines.csv")
    data.table::fwrite(all, out_csv)
    message(sprintf("[ok] Wrote %d lines -> %s", nrow(all), out_csv))
  } else {
    message("[warn] No lines extracted.")
  }
}

if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) { message("[fatal] ", e$message); quit(status = 1) })
}
