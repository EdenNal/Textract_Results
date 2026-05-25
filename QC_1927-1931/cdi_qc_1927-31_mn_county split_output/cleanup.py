import os, glob, csv, unicodedata

def normalize(s: str) -> str:
    s = unicodedata.normalize("NFKD", str(s))
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower()

def explode_double_csv_line(line: str):
    """
    Parses one line that may look like:
      page_0003_tables.csv,"Westmount,Montreal West,,,,1,,,,,,,"
    Returns a list like:
      [page_0003_tables.csv, Westmount, Montreal West, ..., '']
    """
    outer = next(csv.reader([line]))
    if not outer:
        return None

    # Most common case: 2 fields, where field[1] is the whole row as a string
    if len(outer) == 2 and "," in outer[1]:
        inner = next(csv.reader([outer[1]]))
        return [outer[0]] + inner

    # Otherwise, treat it as already split
    return outer

def extract_montreal_rows_from_folder(folder_path, out_csv="montreal_extracted.csv"):
    rows = []
    max_len = 0

    for path in glob.glob(os.path.join(folder_path, "*.csv")):
        # Try common encodings
        for enc in ("utf-8", "utf-8-sig", "cp1252", "latin1"):
            try:
                with open(path, "r", encoding=enc, newline="") as f:
                    for raw_line in f:
                        raw_line = raw_line.strip()
                        if not raw_line:
                            continue
                        row = explode_double_csv_line(raw_line)
                        if row is None:
                            continue

                        # match "montreal" anywhere in the exploded cells
                        if any("montreal" in normalize(cell) for cell in row):
                            rows.append(row)
                            max_len = max(max_len, len(row))
                break
            except UnicodeDecodeError:
                continue

    # Write output with padded columns so it's a rectangular CSV
    out_path = os.path.join(folder_path, out_csv)
    with open(out_path, "w", encoding="utf-8", newline="") as f_out:
        w = csv.writer(f_out)

        # generic headers (you can rename later)
        headers = ["source_file"] + [f"col_{i}" for i in range(1, max_len)]
        w.writerow(headers)

        for r in rows:
            w.writerow(r + [""] * (max_len - len(r)))

    print(f"Saved {len(rows)} rows to: {out_path}")
    return out_path
# extract_montreal_rows_from_folder(
#     r"C:\Users\edeno\Downloads\eden\QC_1927-1931\cdi_qc_1927-31_mn_county split_output",
#     out_csv="Montreal.csv"
# )






import os
import csv

def extract_montreal_rows(repo_path, output_file="MontrealOnly.csv"):
    """
    Search all CSVs in a repository. Any row containing 'montreal'
    is copied to output_file, with the source filename inserted
    as the first column.
    """

    with open(output_file, "w", newline="", encoding="utf-8") as fout:
        writer = csv.writer(fout)

        # header (optional)
        writer.writerow(["source_file", "row_data"])

        for root, _, files in os.walk(repo_path):
            for file in files:
                if not file.lower().endswith(".csv"):
                    continue

                full_path = os.path.join(root, file)

                with open(full_path, newline="", encoding="utf-8") as fin:
                    reader = csv.reader(fin)
                    montreals = ["Montréal", "Montreal"]
                    for row in reader:
                        for cell in row:
                            if "Montréal" in str(cell) or "Montreal":
                                    writer.writerow([file] + row)
                                    break 

    print("Finished writing Montreal rows to", output_file)

#extract_montreal_rows("QC_1927-1931\cdi_qc_1927-31_mn_county split_output")


import csv
import matplotlib.pyplot as plt

def plot_disease_cases(montreal_csv):

    smallpox = []

    with open(montreal_csv, newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader, None)

        for row in reader:
            if len(row) <= 3:
                continue

            val = row[17].strip()
            if val == "":
                smallpox.append(0)

            try:
                smallpox.append(int(val))
            except ValueError:
                continue

    # x = list(range(1, len(smallpox) + 1))
    import pandas as pd

    x = pd.date_range(start="1928-06-01", periods=len(smallpox), freq="MS")



    plt.figure()
    plt.scatter(x, smallpox)
    plt.xticks(ticks=x, labels=[d.strftime("%b-%Y") for d in x], rotation=45, ha='right')


    plt.xlabel("Months")
    plt.ylabel("Measles cases")
    plt.title("Measles Cases")
    plt.show()

plot_disease_cases("QC_1927-1931\montreal_july1928-1931.csv")


