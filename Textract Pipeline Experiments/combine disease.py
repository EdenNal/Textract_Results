import os
import glob
import re
import csv

# # --------- CONFIG ---------
# INPUT_FOLDER =  r"1958_output"
# OUTPUT_FILE =  r"1958_textract_output.csv"  

# # 1-based indexing (Excel-style): row, col
# EXTRACT_MAP = {
#     "Chickenpox": (5, 3),
#     "Mumps": (14, 3)
# }
# # --------------------------



# part_re = re.compile(r"Part(\d+)", re.IGNORECASE)

# def part_number(filename: str):
#     """Extract numeric Part## from filename for natural sorting."""
#     m = part_re.search(filename)
#     return int(m.group(1)) if m else float("inf")

# def safe_int(x: str):
#     if x is None:
#         return None
#     s = str(x).strip().replace(",", "")
#     if s == "":
#         return None
#     try:
#         return int(float(s))
#     except ValueError:
#         return None

# def read_cell(rows, row_1based: int, col_1based: int):
#     r = row_1based - 1
#     c = col_1based - 1
#     if r < 0 or r >= len(rows):
#         return None
#     if c < 0 or c >= len(rows[r]):
#         return None
#     return rows[r][c]

# def main():
#     csv_paths = glob.glob(os.path.join(INPUT_FOLDER, "*.csv"))

#     # Natural sort: Part1, Part2, ... Part10, Part11...
#     csv_paths.sort(key=lambda p: part_number(os.path.basename(p)))

#     if not csv_paths:
#         raise FileNotFoundError(f"No CSV files found in: {INPUT_FOLDER}")

#     out_rows = []
#     for path in csv_paths:
#         filename = os.path.basename(path)

#         with open(path, "r", newline="", encoding="utf-8-sig") as f:
#             rows = list(csv.reader(f))

#         for disease, (row_i, col_i) in EXTRACT_MAP.items():
#             cell = read_cell(rows, row_i, col_i)
#             cases = safe_int(cell)
#             out_rows.append([filename, disease, cases])

#     with open(OUTPUT_FILE, "w", newline="", encoding="utf-8") as f:
#         w = csv.writer(f)
#         w.writerow(["source_file", "disease", "cases"])
#         w.writerows(out_rows)

#     print(f"Done. Wrote {len(out_rows)} rows to: {OUTPUT_FILE}")

# if __name__ == "__main__":
#     main()



import re
import pandas as pd

# INFILE = "1956_output.csv"          # <-- change this
# OUTFILE = "1956-1958_textract_timeseries_chickenpox_mumps.csv"  # <-- output

# # 1) Read (your file has no header)
# df = pd.read_csv(INFILE, header=None, names=["file", "disease", "value"], dtype=str)

# # 2) Keep blanks as NaN; convert numbers safely
# df["value"] = pd.to_numeric(df["value"], errors="coerce")

# # 3) Pivot (NO aggregation)
# wide = df.pivot(index="file", columns="disease", values="value")

# # 4) Extract sorting keys from filename so ordering is chronological/logical
# def sort_keys(fname: str):
#     # Case A: 1956 Part files like ..._1956_..._Part10.csv
#     m = re.search(r"_(\d{4})_.*?_Part(\d+)\.csv$", fname)
#     if m:
#         year = int(m.group(1))
#         week = int(m.group(2))
#         return (year, week)

#     # Case B: 1957/1958 weekly files like ..._1957_...__0002__wk2.csv or ..._1958_...__0001__w1.csv
#     m = re.search(r"_(\d{4})_.*?__0*(\d+)__w(?:k)?(\d+)\.csv$", fname)
#     if m:
#         year = int(m.group(1))
#         # prefer the explicit week number at the end (wkX / wX)
#         week = int(m.group(3))
#         return (year, week)

#     # Fallback: shove unknowns to the end, stable
#     return (9999, 999999)

# wide = wide.sort_index(key=lambda idx: idx.map(sort_keys))

# # 5) OPTIONAL sanity check: keep file in a debug export so you can verify alignment
# debug = wide.reset_index()
# debug.to_csv("debug_with_file.csv", index=False)

# # 6) Now drop file and add clean row number
# wide_out = wide.reset_index(drop=True)
# wide_out.insert(0, "Row", range(1, len(wide_out) + 1))

# # 7) Save final
# wide_out.to_csv(OUTFILE, index=False)
# print(f"Saved {OUTFILE} (and debug_with_file.csv for verification).")
#######################################################################################
# 
# import re
import pandas as pd

INFILE = "1956_output.csv"
OUTFILE = "1956-1958_textract_timeseries_chickenpox_mumps.csv"

# Read exactly as-is
df = pd.read_csv(INFILE, header=None, names=["file", "disease", "value"])

# Pivot (NO aggregation, so values cannot change)
wide = df.pivot(index="file", columns="disease", values="value")

# Sort chronologically based on filename
def sort_key(fname):
    s = str(fname)

    # 1956 Part files
    m = re.search(r"_(\d{4})_.*?_Part(\d+)_tables\.csv$", s)
    if m:
        return (int(m.group(1)), int(m.group(2)))

    # 1957week_0007_tables.csv style
    m = re.search(r"(\d{4})week_0*(\d+)_tables\.csv$", s)
    if m:
        return (int(m.group(1)), int(m.group(2)))

    return (9999, 999999)

wide = wide.sort_index(key=lambda idx: idx.map(sort_key))

# Remove filename and add row number
wide = wide.reset_index(drop=True)
wide.insert(0, "Row", range(1, len(wide) + 1))

# Save
wide.to_csv(OUTFILE, index=False)

print("Done. Values unchanged. Only rearranged.")