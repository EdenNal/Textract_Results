# Load both CSVs
df1 <- read.csv("cdi_ca_1956_wk_prov_dbs_cleaned.csv", header = FALSE, stringsAsFactors = FALSE)
df2 <- read.csv("table-1_cleaned.csv", header = FALSE, stringsAsFactors = FALSE)

nr1 = nrow(df1); nr2 = nrow(df2)
nc1 = ncol(df1); nc2 = ncol(df2)

if (nr1 != nr2) warning("Datasets to compare have different numbers of rows")
if (nc1 != nc2) warning("Datasets to compare have different numbers of columns")

nr = min(nr1, nr2)
nc = min(nc1, nc2)


a <- df1[1:nr, 1:nc]
b <- df2[1:nr, 1:nc]

same <- (a == b)                    
same[is.na(same)] <- FALSE          
same[is.na(a) & is.na(b)] <- TRUE   

percent_match <- mean(same) * 100
cat(sprintf("Match rate: %.2f%%\n", percent_match))

