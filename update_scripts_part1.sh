#!/usr/bin/env bash
# update_scripts_part1.sh
#
# Updates the scripts covering Sections 2 and 3 of the paper:
#   - extraction/AWS_Python_Table_Extraction.py   (Section 2.1)
#   - extraction/xlsx_to_csvs.py                  (Section 3)
#   - postprocessing/Cleaning_fixed.ipynb         (Section 2.2)
#
# Changes:
#   - Removed all hardcoded paths; scripts now take input/output dirs as
#     CLI arguments or read from a configurable constant at the top.
#   - Removed dead code (unused functions, broken cells, exploratory blocks).
#   - The cleaning notebook is consolidated into 5 cells (down from 9) and
#     writes its output to data/textract_cleaned/ and data/manual_cleaned/.
#   - Added module docstrings and usage examples.
#
# This script also creates the new output directories the cleaning notebook
# will write to:
#   - data/textract_cleaned/{1956,1957,1958}/
#   - data/manual_cleaned/{1956,1957,1958}/
#
# Usage:
#   cd ~/Desktop/Textract_Results
#   bash update_scripts_part1.sh
#
# Then review with `git diff`, run any test you want, and commit:
#   git add -A
#   git commit -m \"Clean up extraction and post-processing scripts (Sections 2-3)\"
#   git push

set -e

if [ ! -d ".git" ]; then
    echo "ERROR: run this from the repo root."
    exit 1
fi

echo "==> Creating output directories the cleaning notebook will write to..."
mkdir -p data/textract_cleaned/1956 data/textract_cleaned/1957 data/textract_cleaned/1958
mkdir -p data/manual_cleaned/1956   data/manual_cleaned/1957   data/manual_cleaned/1958

echo ""
echo "==> Writing extraction/AWS_Python_Table_Extraction.py ..."
cat > extraction/AWS_Python_Table_Extraction.py << 'PY_AWS_EOF'
"""
Extract tables from PDF documents using AWS Textract.

Reads PDFs (or images) from an input folder, calls Textract's AnalyzeDocument
with the TABLES feature, and writes two CSVs per input file:
  <name>_tables.csv       -- cell contents
  <name>_confidences.csv  -- corresponding Textract confidence scores

Usage:
    python AWS_Python_Table_Extraction.py <input_dir> <output_dir>

Example (run from repo root):
    python extraction/AWS_Python_Table_Extraction.py \\
        data/pdfs/1956 data/textract_raw/1956

Requires:
    pip install boto3
    AWS credentials configured via `aws configure` or environment variables.
"""

import os
import argparse
import boto3


# ------------ Textract helpers ------------

def extract_text(cell_block, blocks_map):
    """Concatenate WORDs and mark selected checkboxes as 'X'."""
    parts = []
    for rel in cell_block.get('Relationships', []):
        if rel['Type'] != 'CHILD':
            continue
        for child_id in rel['Ids']:
            b = blocks_map[child_id]
            bt = b.get('BlockType')
            if bt == 'WORD':
                w = b.get('Text', '')
                # Quote numbers containing commas so the CSV stays valid
                if ',' in w and w.replace(',', '').isdigit():
                    parts.append(f'"{w}"')
                else:
                    parts.append(w)
            elif bt == 'SELECTION_ELEMENT' and b.get('SelectionStatus') == 'SELECTED':
                parts.append('X')
    return ' '.join(p for p in parts if p).strip()


def get_rows_and_confidence(table_result, blocks_map):
    """Build parallel maps: rows[r][c] -> text, conf[r][c] -> confidence."""
    rows, conf = {}, {}
    for rel in table_result.get('Relationships', []):
        if rel['Type'] != 'CHILD':
            continue
        for child_id in rel['Ids']:
            cell = blocks_map[child_id]
            if cell.get('BlockType') != 'CELL':
                continue
            r = cell['RowIndex']
            c = cell['ColumnIndex']
            rows.setdefault(r, {})
            conf.setdefault(r, {})
            rows[r][c] = extract_text(cell, blocks_map)
            conf[r][c] = cell.get('Confidence')
    return rows, conf


def analyze_tables(file_path, region='us-east-1'):
    """Run Textract (TABLES) and return its TABLE blocks plus a full blocks map."""
    with open(file_path, 'rb') as f:
        content = f.read()
    client = boto3.client('textract', region_name=region)
    resp = client.analyze_document(
        Document={'Bytes': bytearray(content)},
        FeatureTypes=['TABLES'],
    )
    blocks = resp.get('Blocks', [])
    blocks_map = {b['Id']: b for b in blocks}
    table_blocks = [b for b in blocks if b.get('BlockType') == 'TABLE']
    return table_blocks, blocks_map


# ------------ CSV builders ------------

def build_csvs_for_table(table_block, blocks_map, table_index):
    """Return (text_csv_string, confidence_csv_string) for one detected table."""
    rows_map, conf_map = get_rows_and_confidence(table_block, blocks_map)
    if not rows_map:
        header = f"Table: Table_{table_index}"
        return header, header

    row_indices = sorted(rows_map.keys())
    col_indices = sorted({c for r in row_indices for c in rows_map[r]})

    text_lines = [f"Table: Table_{table_index}"]
    conf_lines = [f"Table: Table_{table_index}"]
    for r in row_indices:
        text_lines.append(",".join(rows_map.get(r, {}).get(c, "") for c in col_indices))
        scores = []
        for c in col_indices:
            v = conf_map.get(r, {}).get(c, "")
            scores.append(f"{v:.2f}" if isinstance(v, (int, float)) else "")
        conf_lines.append(",".join(scores))

    return "\n".join(text_lines), "\n".join(conf_lines)


def build_all_csvs(file_path):
    """Run Textract on one file and return its combined (tables_csv, confidences_csv)."""
    table_blocks, blocks_map = analyze_tables(file_path)
    if not table_blocks:
        return "NO TABLE FOUND", "NO TABLE FOUND"

    text_parts, conf_parts = [], []
    for i, tbl in enumerate(table_blocks, 1):
        t, c = build_csvs_for_table(tbl, blocks_map, i)
        text_parts.append(t)
        conf_parts.append(c)

    tables_csv = "\n".join(ln for ln in "\n".join(text_parts).splitlines() if ln.strip())
    conf_csv = "\n".join(ln for ln in "\n".join(conf_parts).splitlines() if ln.strip())
    return tables_csv, conf_csv


# ------------ Writer ------------

def write_csv(path, text):
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    normalized = "\r\n".join(text.split("\n"))
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        f.write(normalized)


# ------------ Main ------------

def main(input_dir, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    valid_exts = ('.pdf', '.png', '.jpg', '.jpeg', '.tif', '.tiff')
    files = sorted(f for f in os.listdir(input_dir) if f.lower().endswith(valid_exts))
    if not files:
        raise FileNotFoundError(f"No supported files found in {input_dir}")

    for fname in files:
        in_path = os.path.join(input_dir, fname)
        tables_csv, conf_csv = build_all_csvs(in_path)
        base = os.path.splitext(fname)[0]
        write_csv(os.path.join(output_dir, f"{base}_tables.csv"), tables_csv)
        write_csv(os.path.join(output_dir, f"{base}_confidences.csv"), conf_csv)
        print(f"Processed {fname}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Extract tables from PDFs using AWS Textract."
    )
    parser.add_argument("input_dir", help="Directory of input PDF files.")
    parser.add_argument("output_dir", help="Directory to write extracted CSVs.")
    args = parser.parse_args()
    main(args.input_dir, args.output_dir)
PY_AWS_EOF

echo "==> Writing extraction/xlsx_to_csvs.py ..."
cat > extraction/xlsx_to_csvs.py << 'PY_XLSX_EOF'
"""
Convert each sheet of an Excel workbook into a CSV file.

Used to derive the manually-entered ground-truth CSVs (one per week) from the
original Excel workbooks of the Canada Notifiable Disease Dataset.

Usage:
    python xlsx_to_csvs.py <input_xlsx> <output_dir>

Example (run from repo root):
    python extraction/xlsx_to_csvs.py \\
        data/source_xlsx/cdi_ca_1956_wk_prov_dbs.xlsx data/manual/1956

Requires:
    pip install openpyxl
"""

import csv
import argparse
from pathlib import Path
from openpyxl import load_workbook


def safe_name(name: str) -> str:
    """Strip filesystem-illegal characters from a sheet name."""
    for ch in '\\/:*?"<>|':
        name = name.replace(ch, "_")
    return name.strip()[:120] or "Sheet"


def sheet_to_csv(ws, out_path: Path):
    with out_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        for row in ws.iter_rows(values_only=True):
            # keep empty cells as empty strings so columns don't shift
            w.writerow(["" if v is None else v for v in row])


def xlsx_to_csvs(input_xlsx: str, output_dir: str):
    input_path = Path(input_xlsx)
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    wb = load_workbook(input_path, data_only=True)
    for i, ws in enumerate(wb.worksheets, 1):
        out = out_dir / f"{input_path.stem}__{i:04d}__{safe_name(ws.title)}.csv"
        sheet_to_csv(ws, out)
        print(f"Wrote {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Split an Excel workbook into one CSV per sheet."
    )
    parser.add_argument("input_xlsx", help="Path to input .xlsx file.")
    parser.add_argument("output_dir", help="Directory to write CSV files.")
    args = parser.parse_args()
    xlsx_to_csvs(args.input_xlsx, args.output_dir)
PY_XLSX_EOF

echo "==> Writing postprocessing/Cleaning_fixed.ipynb ..."
base64 -d > postprocessing/Cleaning_fixed.ipynb << 'NB_B64_EOF'
ewogImNlbGxzIjogWwogIHsKICAgImNlbGxfdHlwZSI6ICJtYXJrZG93biIsCiAgICJpZCI6ICJk
NjBkZDY1OSIsCiAgICJtZXRhZGF0YSI6IHt9LAogICAic291cmNlIjogWwogICAgIiMgUG9zdC1w
cm9jZXNzaW5nIG9mIFRleHRyYWN0IG91dHB1dFxuIiwKICAgICJcbiIsCiAgICAiQ2xlYW5zIHRo
ZSByYXcgVGV4dHJhY3QgQ1NWIG91dHB1dCBvZiB0aGUgMTk1NiBDTkREIHRhYmxlcyB0byBhIGZv
cm1cbiIsCiAgICAic3VpdGFibGUgZm9yIGNlbGwtYnktY2VsbCBjb21wYXJpc29uIHdpdGggdGhl
IG1hbnVhbCBncm91bmQgdHJ1dGguXG4iLAogICAgIkltcGxlbWVudHMgdGhlIHBvc3QtcHJvY2Vz
c2luZyBzdGVwcyBkZXNjcmliZWQgaW4gU2VjdGlvbiAyLjIgb2YgdGhlXG4iLAogICAgInBhcGVy
LlxuIiwKICAgICJcbiIsCiAgICAiKipQaXBlbGluZSAoYXBwbGllZCB0byBib3RoIFRleHRyYWN0
IGFuZCBtYW51YWwgQ1NWcyk6KipcbiIsCiAgICAiXG4iLAogICAgIjEuIFJlbW92ZSBwcmVhbWJs
ZSByb3dzIHRoYXQgcHJlY2VkZSB0aGUgZmlyc3QgZGF0YSByb3cgKFRleHRyYWN0IG9ubHk7XG4i
LAogICAgIiAgIHRoZSBtYW51YWwgQ1NWcyBoYXZlIG5vIHByZWFtYmxlKS5cbiIsCiAgICAiMi4g
UmVtb3ZlIHRoZSBmaXJzdCB0d28gY29sdW1ucyAocm93IGluZGV4IGFuZCBkaXNlYXNlIGxhYmVs
IGNvbHVtbnMsXG4iLAogICAgIiAgIHdoaWNoIGFyZSBub3QgcGFydCBvZiB0aGUgY2VsbCBjb21w
YXJpc29uKS5cbiIsCiAgICAiMy4gUGFkIHNob3J0IHJvd3Mgd2l0aCBhIHBsYWNlaG9sZGVyIHNv
IGFsbCByb3dzIGluIGEgZmlsZSBzaGFyZSB0aGUgc2FtZVxuIiwKICAgICIgICBjb2x1bW4gY291
bnQuXG4iLAogICAgIlxuIiwKICAgICIqKklucHV0cyoqXG4iLAogICAgIi0gYGRhdGEvdGV4dHJh
Y3RfcmF3LzE5NTYvY2RpX2NhXzE5NTZfd2tfcHJvdl9kYnNfUGFydHtpfV90YWJsZXMuY3N2YFxu
IiwKICAgICItIGBkYXRhL3RleHRyYWN0X3Jhdy8xOTU2L2NkaV9jYV8xOTU2X3drX3Byb3ZfZGJz
X1BhcnR7aX1fY29uZmlkZW5jZXMuY3N2YCAqKG9wdGlvbmFsKSpcbiIsCiAgICAiLSBgZGF0YS9t
YW51YWwvMTk1Ni9jZGlfY2FfMTk1Nl93a19wcm92X2Ric19QYXJ0e2l9LmNzdmBcbiIsCiAgICAi
XG4iLAogICAgIioqT3V0cHV0cyoqXG4iLAogICAgIi0gYGRhdGEvdGV4dHJhY3RfY2xlYW5lZC8x
OTU2L2NkaV9jYV8xOTU2X3drX3Byb3ZfZGJzX1BhcnR7aX1fdGFibGVzLmNzdmBcbiIsCiAgICAi
LSBgZGF0YS90ZXh0cmFjdF9jbGVhbmVkLzE5NTYvY2RpX2NhXzE5NTZfd2tfcHJvdl9kYnNfUGFy
dHtpfV9jb25maWRlbmNlcy5jc3ZgICooaWYgaW5wdXQgcHJlc2VudCkqXG4iLAogICAgIi0gYGRh
dGEvbWFudWFsX2NsZWFuZWQvMTk1Ni9jZGlfY2FfMTk1Nl93a19wcm92X2Ric19QYXJ0e2l9LmNz
dmBcbiIsCiAgICAiXG4iLAogICAgIk91dHB1dHMgYXJlIHdyaXR0ZW4gaW4gdGhlIGZvcm0gZXhw
ZWN0ZWQgYnkgYHBvc3Rwcm9jZXNzaW5nL2NvbWJpbmUuaXB5bmJgLFxuIiwKICAgICJ3aGljaCBi
dWlsZHMgdGhlIGNlbGwtY29tcGFyaXNvbiB0YWJsZSB1c2VkIGluIFNlY3Rpb24gNS4xLlxuIgog
ICBdCiAgfSwKICB7CiAgICJjZWxsX3R5cGUiOiAiY29kZSIsCiAgICJleGVjdXRpb25fY291bnQi
OiBudWxsLAogICAiaWQiOiAiMDZmNmM0NzMiLAogICAibWV0YWRhdGEiOiB7fSwKICAgIm91dHB1
dHMiOiBbXSwKICAgInNvdXJjZSI6IFsKICAgICIjIENvbmZpZ3VyYXRpb24uIEFsbCBwYXRocyBh
cmUgcmVsYXRpdmUgdG8gdGhlIHJlcG9zaXRvcnkgcm9vdC5cbiIsCiAgICAiIyBSdW4gdGhpcyBu
b3RlYm9vayBmcm9tIHRoZSByZXBvc2l0b3J5IHJvb3QsIG9yIGFkanVzdCBSRVBPX1JPT1QgYmVs
b3cuXG4iLAogICAgIlxuIiwKICAgICJpbXBvcnQgb3NcbiIsCiAgICAiXG4iLAogICAgIlJFUE9f
Uk9PVCA9IFwiLi5cIiAgICMgdGhpcyBub3RlYm9vayBsaXZlcyBpbiBwb3N0cHJvY2Vzc2luZy9c
biIsCiAgICAiXG4iLAogICAgIllFQVIgPSAxOTU2XG4iLAogICAgIk5fV0VFS1MgPSA1MlxuIiwK
ICAgICJGSUxFX1BSRUZJWCA9IGZcImNkaV9jYV97WUVBUn1fd2tfcHJvdl9kYnNfUGFydFwiXG4i
LAogICAgIlxuIiwKICAgICJURVhUUkFDVF9JTlBVVF9ESVIgID0gb3MucGF0aC5qb2luKFJFUE9f
Uk9PVCwgXCJkYXRhXCIsIFwidGV4dHJhY3RfcmF3XCIsICAgICBzdHIoWUVBUikpXG4iLAogICAg
Ik1BTlVBTF9JTlBVVF9ESVIgICAgPSBvcy5wYXRoLmpvaW4oUkVQT19ST09ULCBcImRhdGFcIiwg
XCJtYW51YWxcIiwgICAgICAgICAgIHN0cihZRUFSKSlcbiIsCiAgICAiVEVYVFJBQ1RfT1VUUFVU
X0RJUiA9IG9zLnBhdGguam9pbihSRVBPX1JPT1QsIFwiZGF0YVwiLCBcInRleHRyYWN0X2NsZWFu
ZWRcIiwgc3RyKFlFQVIpKVxuIiwKICAgICJNQU5VQUxfT1VUUFVUX0RJUiAgID0gb3MucGF0aC5q
b2luKFJFUE9fUk9PVCwgXCJkYXRhXCIsIFwibWFudWFsX2NsZWFuZWRcIiwgICBzdHIoWUVBUikp
XG4iLAogICAgIlxuIiwKICAgICIjIFRleHRyYWN0IG91dHB1dCBiZWdpbnMgd2l0aCBhIHByZWFt
YmxlIChjb2x1bW4gaGVhZGVycywgZm9vdG5vdGVzLCBldGMpLlxuIiwKICAgICIjIFRoZSBmaXJz
dCBkYXRhIHJvdyBiZWdpbnMgd2l0aCB0aGUgdmFsdWUgXCIxXCIgKHRoZSByb3cgaW5kZXggaW4g
dGhlIHNvdXJjZSBQREYpLlxuIiwKICAgICJGSVJTVF9EQVRBX1JPV19NQVJLRVIgPSBcIjFcIlxu
IiwKICAgICJcbiIsCiAgICAiIyBQbGFjZWhvbGRlciB1c2VkIHdoZW4gcGFkZGluZyBzaG9ydCBy
b3dzIHRvIHRoZSBmaWxlJ3MgbWF4aW11bSB3aWR0aC5cbiIsCiAgICAiUEFEX1BMQUNFSE9MREVS
ID0gXCJGSUxMRVJcIlxuIgogICBdCiAgfSwKICB7CiAgICJjZWxsX3R5cGUiOiAiY29kZSIsCiAg
ICJleGVjdXRpb25fY291bnQiOiBudWxsLAogICAiaWQiOiAiNWRmMzQ3NmMiLAogICAibWV0YWRh
dGEiOiB7fSwKICAgIm91dHB1dHMiOiBbXSwKICAgInNvdXJjZSI6IFsKICAgICIjIENsZWFuaW5n
IGhlbHBlcnMuXG4iLAogICAgIlxuIiwKICAgICJpbXBvcnQgY3N2XG4iLAogICAgIlxuIiwKICAg
ICJkZWYgY291bnRfcm93c191bnRpbF92YWx1ZShmaWxlX3BhdGgsIHN0b3BfdmFsdWUpOlxuIiwK
ICAgICIgICAgXCJcIlwiUmV0dXJuIHRoZSBudW1iZXIgb2Ygcm93cyBwcmVjZWRpbmcgdGhlIGZp
cnN0IHJvdyB3aG9zZSBmaXJzdCBjZWxsXG4iLAogICAgIiAgICBlcXVhbHMgc3RvcF92YWx1ZS4g
SWYgbm8gc3VjaCByb3cgZXhpc3RzLCByZXR1cm4gMCAoZG8gbm90IHRyaW0pLlwiXCJcIlxuIiwK
ICAgICIgICAgd2l0aCBvcGVuKGZpbGVfcGF0aCwgXCJyXCIsIG5ld2xpbmU9XCJcIiwgZW5jb2Rp
bmc9XCJ1dGYtOC1zaWdcIikgYXMgZjpcbiIsCiAgICAiICAgICAgICBmb3IgaSwgcm93IGluIGVu
dW1lcmF0ZShjc3YucmVhZGVyKGYpKTpcbiIsCiAgICAiICAgICAgICAgICAgaWYgcm93IGFuZCBy
b3dbMF0gPT0gc3RvcF92YWx1ZTpcbiIsCiAgICAiICAgICAgICAgICAgICAgIHJldHVybiBpXG4i
LAogICAgIiAgICByZXR1cm4gMFxuIiwKICAgICJcbiIsCiAgICAiXG4iLAogICAgImRlZiByZW1v
dmVfZmlyc3Rfbl9yb3dzKGlucHV0X3BhdGgsIG91dHB1dF9wYXRoLCBuKTpcbiIsCiAgICAiICAg
IFwiXCJcIkNvcHkgaW5wdXRfcGF0aCB0byBvdXRwdXRfcGF0aCwgZHJvcHBpbmcgdGhlIGZpcnN0
IG4gcm93cy5cIlwiXCJcbiIsCiAgICAiICAgIHdpdGggb3BlbihpbnB1dF9wYXRoLCBcInJcIiwg
bmV3bGluZT1cIlwiLCBlbmNvZGluZz1cInV0Zi04LXNpZ1wiKSBhcyBmaW46XG4iLAogICAgIiAg
ICAgICAgcm93cyA9IGxpc3QoY3N2LnJlYWRlcihmaW4pKVtuOl1cbiIsCiAgICAiICAgIHdpdGgg
b3BlbihvdXRwdXRfcGF0aCwgXCJ3XCIsIG5ld2xpbmU9XCJcIiwgZW5jb2Rpbmc9XCJ1dGYtOFwi
KSBhcyBmb3V0OlxuIiwKICAgICIgICAgICAgIGNzdi53cml0ZXIoZm91dCkud3JpdGVyb3dzKHJv
d3MpXG4iLAogICAgIlxuIiwKICAgICJcbiIsCiAgICAiZGVmIHJlbW92ZV9maXJzdF9uX2NvbHVt
bnMoaW5wdXRfcGF0aCwgb3V0cHV0X3BhdGgsIG4pOlxuIiwKICAgICIgICAgXCJcIlwiQ29weSBp
bnB1dF9wYXRoIHRvIG91dHB1dF9wYXRoLCBkcm9wcGluZyB0aGUgZmlyc3QgbiBjb2x1bW5zIG9m
IGV2ZXJ5IHJvdy5cIlwiXCJcbiIsCiAgICAiICAgIHdpdGggb3BlbihpbnB1dF9wYXRoLCBcInJc
IiwgbmV3bGluZT1cIlwiLCBlbmNvZGluZz1cInV0Zi04LXNpZ1wiKSBhcyBmaW46XG4iLAogICAg
IiAgICAgICAgcm93cyA9IFtyb3dbbjpdIGZvciByb3cgaW4gY3N2LnJlYWRlcihmaW4pXVxuIiwK
ICAgICIgICAgd2l0aCBvcGVuKG91dHB1dF9wYXRoLCBcIndcIiwgbmV3bGluZT1cIlwiLCBlbmNv
ZGluZz1cInV0Zi04XCIpIGFzIGZvdXQ6XG4iLAogICAgIiAgICAgICAgY3N2LndyaXRlcihmb3V0
KS53cml0ZXJvd3Mocm93cylcbiIsCiAgICAiXG4iLAogICAgIlxuIiwKICAgICJkZWYgcGFkX3Jv
d3MoaW5wdXRfcGF0aCwgb3V0cHV0X3BhdGgsIHBsYWNlaG9sZGVyPVBBRF9QTEFDRUhPTERFUik6
XG4iLAogICAgIiAgICBcIlwiXCJDb3B5IGlucHV0X3BhdGggdG8gb3V0cHV0X3BhdGgsIHBhZGRp
bmcgc2hvcnQgcm93cyB3aXRoIHBsYWNlaG9sZGVyXG4iLAogICAgIiAgICBzbyBldmVyeSByb3cg
aGFzIHRoZSBzYW1lIG51bWJlciBvZiBjb2x1bW5zIGFzIHRoZSBmaWxlJ3Mgd2lkZXN0IHJvdy5c
IlwiXCJcbiIsCiAgICAiICAgIHdpdGggb3BlbihpbnB1dF9wYXRoLCBcInJcIiwgbmV3bGluZT1c
IlwiLCBlbmNvZGluZz1cInV0Zi04LXNpZ1wiKSBhcyBmaW46XG4iLAogICAgIiAgICAgICAgcm93
cyA9IGxpc3QoY3N2LnJlYWRlcihmaW4pKVxuIiwKICAgICIgICAgbWF4X2NvbHMgPSBtYXgoKGxl
bihyKSBmb3IgciBpbiByb3dzKSwgZGVmYXVsdD0wKVxuIiwKICAgICIgICAgd2l0aCBvcGVuKG91
dHB1dF9wYXRoLCBcIndcIiwgbmV3bGluZT1cIlwiLCBlbmNvZGluZz1cInV0Zi04XCIpIGFzIGZv
dXQ6XG4iLAogICAgIiAgICAgICAgd3JpdGVyID0gY3N2LndyaXRlcihmb3V0KVxuIiwKICAgICIg
ICAgICAgIGZvciByb3cgaW4gcm93czpcbiIsCiAgICAiICAgICAgICAgICAgaWYgbGVuKHJvdykg
PCBtYXhfY29sczpcbiIsCiAgICAiICAgICAgICAgICAgICAgIHJvdyA9IHJvdyArIFtwbGFjZWhv
bGRlcl0gKiAobWF4X2NvbHMgLSBsZW4ocm93KSlcbiIsCiAgICAiICAgICAgICAgICAgd3JpdGVy
LndyaXRlcm93KHJvdylcbiIKICAgXQogIH0sCiAgewogICAiY2VsbF90eXBlIjogImNvZGUiLAog
ICAiZXhlY3V0aW9uX2NvdW50IjogbnVsbCwKICAgImlkIjogIjY5MzkwZDE5IiwKICAgIm1ldGFk
YXRhIjoge30sCiAgICJvdXRwdXRzIjogW10sCiAgICJzb3VyY2UiOiBbCiAgICAiIyBDbGVhbiBv
bmUgVGV4dHJhY3QgQ1NWIChwcmVhbWJsZSByZW1vdmFsLCBjb2x1bW4gdHJpbSwgcGFkZGluZyku
XG4iLAogICAgIlxuIiwKICAgICJpbXBvcnQgdGVtcGZpbGVcbiIsCiAgICAiXG4iLAogICAgImRl
ZiBjbGVhbl90ZXh0cmFjdF9maWxlKHNyYywgZHN0KTpcbiIsCiAgICAiICAgIFwiXCJcIlJ1biB0
aGUgZnVsbCBUZXh0cmFjdCBjbGVhbmluZyBwaXBlbGluZSBvbiBhIHNpbmdsZSBDU1YuXCJcIlwi
XG4iLAogICAgIiAgICBuX3ByZWFtYmxlID0gY291bnRfcm93c191bnRpbF92YWx1ZShzcmMsIEZJ
UlNUX0RBVEFfUk9XX01BUktFUilcbiIsCiAgICAiICAgIHdpdGggdGVtcGZpbGUuTmFtZWRUZW1w
b3JhcnlGaWxlKGRlbGV0ZT1GYWxzZSwgc3VmZml4PVwiLmNzdlwiLCBtb2RlPVwid1wiKSBhcyB0
bXAxLCBcXFxuIiwKICAgICIgICAgICAgICB0ZW1wZmlsZS5OYW1lZFRlbXBvcmFyeUZpbGUoZGVs
ZXRlPUZhbHNlLCBzdWZmaXg9XCIuY3N2XCIsIG1vZGU9XCJ3XCIpIGFzIHRtcDI6XG4iLAogICAg
IiAgICAgICAgdG1wMV9wYXRoLCB0bXAyX3BhdGggPSB0bXAxLm5hbWUsIHRtcDIubmFtZVxuIiwK
ICAgICIgICAgdHJ5OlxuIiwKICAgICIgICAgICAgIHJlbW92ZV9maXJzdF9uX3Jvd3Moc3JjLCB0
bXAxX3BhdGgsIG5fcHJlYW1ibGUpXG4iLAogICAgIiAgICAgICAgcmVtb3ZlX2ZpcnN0X25fY29s
dW1ucyh0bXAxX3BhdGgsIHRtcDJfcGF0aCwgbj0yKVxuIiwKICAgICIgICAgICAgIHBhZF9yb3dz
KHRtcDJfcGF0aCwgZHN0KVxuIiwKICAgICIgICAgZmluYWxseTpcbiIsCiAgICAiICAgICAgICBv
cy5yZW1vdmUodG1wMV9wYXRoKVxuIiwKICAgICIgICAgICAgIG9zLnJlbW92ZSh0bXAyX3BhdGgp
XG4iLAogICAgIlxuIiwKICAgICJcbiIsCiAgICAiZGVmIGNsZWFuX21hbnVhbF9maWxlKHNyYywg
ZHN0KTpcbiIsCiAgICAiICAgIFwiXCJcIlJ1biB0aGUgbWFudWFsLUNTViBjbGVhbmluZyBwaXBl
bGluZSAoY29sdW1uIHRyaW0sIHBhZGRpbmc7IG5vIHByZWFtYmxlKS5cIlwiXCJcbiIsCiAgICAi
ICAgIHdpdGggdGVtcGZpbGUuTmFtZWRUZW1wb3JhcnlGaWxlKGRlbGV0ZT1GYWxzZSwgc3VmZml4
PVwiLmNzdlwiLCBtb2RlPVwid1wiKSBhcyB0bXA6XG4iLAogICAgIiAgICAgICAgdG1wX3BhdGgg
PSB0bXAubmFtZVxuIiwKICAgICIgICAgdHJ5OlxuIiwKICAgICIgICAgICAgIHJlbW92ZV9maXJz
dF9uX2NvbHVtbnMoc3JjLCB0bXBfcGF0aCwgbj0yKVxuIiwKICAgICIgICAgICAgIHBhZF9yb3dz
KHRtcF9wYXRoLCBkc3QpXG4iLAogICAgIiAgICBmaW5hbGx5OlxuIiwKICAgICIgICAgICAgIG9z
LnJlbW92ZSh0bXBfcGF0aClcbiIKICAgXQogIH0sCiAgewogICAiY2VsbF90eXBlIjogImNvZGUi
LAogICAiZXhlY3V0aW9uX2NvdW50IjogbnVsbCwKICAgImlkIjogIjE3OGZiYmY4IiwKICAgIm1l
dGFkYXRhIjoge30sCiAgICJvdXRwdXRzIjogW10sCiAgICJzb3VyY2UiOiBbCiAgICAiIyBSdW4g
dGhlIGNsZWFuaW5nIHBpcGVsaW5lIGZvciB0aGUgZnVsbCB5ZWFyLlxuIiwKICAgICJcbiIsCiAg
ICAib3MubWFrZWRpcnMoVEVYVFJBQ1RfT1VUUFVUX0RJUiwgZXhpc3Rfb2s9VHJ1ZSlcbiIsCiAg
ICAib3MubWFrZWRpcnMoTUFOVUFMX09VVFBVVF9ESVIsICAgZXhpc3Rfb2s9VHJ1ZSlcbiIsCiAg
ICAiXG4iLAogICAgInByb2Nlc3NlZCA9IDBcbiIsCiAgICAic2tpcHBlZCA9IFtdXG4iLAogICAg
IlxuIiwKICAgICJmb3IgaSBpbiByYW5nZSgxLCBOX1dFRUtTICsgMSk6XG4iLAogICAgIiAgICBi
YXNlID0gZlwie0ZJTEVfUFJFRklYfXtpfVwiXG4iLAogICAgIlxuIiwKICAgICIgICAgIyBUZXh0
cmFjdDogdGFibGVzIChyZXF1aXJlZClcbiIsCiAgICAiICAgIHRfc3JjID0gb3MucGF0aC5qb2lu
KFRFWFRSQUNUX0lOUFVUX0RJUiwgIGZcIntiYXNlfV90YWJsZXMuY3N2XCIpXG4iLAogICAgIiAg
ICB0X2RzdCA9IG9zLnBhdGguam9pbihURVhUUkFDVF9PVVRQVVRfRElSLCBmXCJ7YmFzZX1fdGFi
bGVzLmNzdlwiKVxuIiwKICAgICIgICAgaWYgb3MucGF0aC5leGlzdHModF9zcmMpOlxuIiwKICAg
ICIgICAgICAgIGNsZWFuX3RleHRyYWN0X2ZpbGUodF9zcmMsIHRfZHN0KVxuIiwKICAgICIgICAg
ZWxzZTpcbiIsCiAgICAiICAgICAgICBza2lwcGVkLmFwcGVuZCh0X3NyYylcbiIsCiAgICAiXG4i
LAogICAgIiAgICAjIFRleHRyYWN0OiBjb25maWRlbmNlcyAob3B0aW9uYWw7IHRoZSBwYXBlcidz
IGZpZ3VyZXMgZG9uJ3QgdXNlIHRoZW0pXG4iLAogICAgIiAgICBjX3NyYyA9IG9zLnBhdGguam9p
bihURVhUUkFDVF9JTlBVVF9ESVIsICBmXCJ7YmFzZX1fY29uZmlkZW5jZXMuY3N2XCIpXG4iLAog
ICAgIiAgICBjX2RzdCA9IG9zLnBhdGguam9pbihURVhUUkFDVF9PVVRQVVRfRElSLCBmXCJ7YmFz
ZX1fY29uZmlkZW5jZXMuY3N2XCIpXG4iLAogICAgIiAgICBpZiBvcy5wYXRoLmV4aXN0cyhjX3Ny
Yyk6XG4iLAogICAgIiAgICAgICAgY2xlYW5fdGV4dHJhY3RfZmlsZShjX3NyYywgY19kc3QpXG4i
LAogICAgIlxuIiwKICAgICIgICAgIyBNYW51YWxcbiIsCiAgICAiICAgIG1fc3JjID0gb3MucGF0
aC5qb2luKE1BTlVBTF9JTlBVVF9ESVIsICBmXCJ7YmFzZX0uY3N2XCIpXG4iLAogICAgIiAgICBt
X2RzdCA9IG9zLnBhdGguam9pbihNQU5VQUxfT1VUUFVUX0RJUiwgZlwie2Jhc2V9LmNzdlwiKVxu
IiwKICAgICIgICAgaWYgb3MucGF0aC5leGlzdHMobV9zcmMpOlxuIiwKICAgICIgICAgICAgIGNs
ZWFuX21hbnVhbF9maWxlKG1fc3JjLCBtX2RzdClcbiIsCiAgICAiICAgIGVsc2U6XG4iLAogICAg
IiAgICAgICAgc2tpcHBlZC5hcHBlbmQobV9zcmMpXG4iLAogICAgIlxuIiwKICAgICIgICAgcHJv
Y2Vzc2VkICs9IDFcbiIsCiAgICAiXG4iLAogICAgInByaW50KGZcIlByb2Nlc3NlZCB7cHJvY2Vz
c2VkfSB3ZWVrcy5cIilcbiIsCiAgICAicHJpbnQoZlwiT3V0cHV0OlwiKVxuIiwKICAgICJwcmlu
dChmXCIgIHtURVhUUkFDVF9PVVRQVVRfRElSfS9cIilcbiIsCiAgICAicHJpbnQoZlwiICB7TUFO
VUFMX09VVFBVVF9ESVJ9L1wiKVxuIiwKICAgICJpZiBza2lwcGVkOlxuIiwKICAgICIgICAgcHJp
bnQoZlwiXFxuTWlzc2luZyBpbnB1dHMgKHtsZW4oc2tpcHBlZCl9KTpcIilcbiIsCiAgICAiICAg
IGZvciBzIGluIHNraXBwZWRbOjVdOlxuIiwKICAgICIgICAgICAgIHByaW50KGZcIiAge3N9XCIp
XG4iLAogICAgIiAgICBpZiBsZW4oc2tpcHBlZCkgPiA1OlxuIiwKICAgICIgICAgICAgIHByaW50
KGZcIiAgLi4uIGFuZCB7bGVuKHNraXBwZWQpIC0gNX0gbW9yZVwiKVxuIgogICBdCiAgfQogXSwK
ICJtZXRhZGF0YSI6IHsKICAia2VybmVsc3BlYyI6IHsKICAgImRpc3BsYXlfbmFtZSI6ICJQeXRo
b24gMyIsCiAgICJsYW5ndWFnZSI6ICJweXRob24iLAogICAibmFtZSI6ICJweXRob24zIgogIH0s
CiAgImxhbmd1YWdlX2luZm8iOiB7CiAgICJuYW1lIjogInB5dGhvbiIKICB9CiB9LAogIm5iZm9y
bWF0IjogNCwKICJuYmZvcm1hdF9taW5vciI6IDUKfQo=
NB_B64_EOF

echo ""
echo "==> Done. Summary of changes:"
echo ""
echo "  Modified files:"
echo "    extraction/AWS_Python_Table_Extraction.py"
echo "    extraction/xlsx_to_csvs.py"
echo "    postprocessing/Cleaning_fixed.ipynb"
echo ""
echo "  New directories:"
echo "    data/textract_cleaned/{1956,1957,1958}/"
echo "    data/manual_cleaned/{1956,1957,1958}/"
echo ""
echo "Next steps:"
echo "  git diff                          # review the script changes"
echo "  git status                        # see the new directories"
echo "  git add -A"
echo "  git commit -m \"Clean up Section 2-3 scripts\""
echo "  git push"
echo ""
echo "To regenerate the cleaned 1956 data (Section 2.2 of the paper), run:"
echo "  jupyter nbconvert --to notebook --execute --inplace \\"
echo "    postprocessing/Cleaning_fixed.ipynb"
