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
