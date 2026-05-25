#!/usr/bin/env python3
"""
compare_csv_rows_stdlib.py

Compare two CSV files entry-by-entry and report the total number of differences per row,
using only Python’s standard library.
Usage:
    python compare_csv_rows_stdlib.py file1.csv file2.csv [--output diff_counts.csv]
example:
    python compare_csv_rows_stdlib.py Prompt3.csv Prompt7.csv -o row_diffs.csv
"""

import sys
import argparse
import csv
from itertools import zip_longest

def parse_args():
    p = argparse.ArgumentParser(
        description="Compare two CSVs (stdlib) and count per-row differences."
    )
    p.add_argument("csv1", help="Path to first CSV file")
    p.add_argument("csv2", help="Path to second CSV file")
    p.add_argument(
        "-o", "--output",
        help="Optional path to save the difference counts (CSV)",
        default=None,
    )
    return p.parse_args()

def main():
    args = parse_args()

    diff_results = []
    # Open both files and iterate in parallel
    with open(args.csv1, newline='') as f1, open(args.csv2, newline='') as f2:
        reader1 = csv.reader(f1)
        reader2 = csv.reader(f2)

        for row_idx, (row1, row2) in enumerate(zip_longest(reader1, reader2), start=1):
            # Detect mismatched row counts
            if row1 is None or row2 is None:
                sys.exit(f"ERROR: Number of rows differs at row {row_idx}.")

            # Detect mismatched column counts
            if len(row1) != len(row2):
                sys.exit(
                    f"ERROR: Row {row_idx} has {len(row1)} columns in {args.csv1} "
                    f"but {len(row2)} in {args.csv2}."
                )

            # Count cell-by-cell differences
            diff_count = sum(1 for a, b in zip(row1, row2) if a != b)
            diff_results.append((row_idx, diff_count))

    # Print to stdout
    print("row_index,num_differences")
    for idx, count in diff_results:
        print(f"{idx},{count}")

    # Optionally save to CSV
    if args.output:
        with open(args.output, 'w', newline='') as out:
            writer = csv.writer(out)
            writer.writerow(["row_index", "num_differences"])
            writer.writerows(diff_results)
        print(f"\nSaved difference counts to {args.output}")

if __name__ == "__main__":
    main()
