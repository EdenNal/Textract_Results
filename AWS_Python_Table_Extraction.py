import os
import sys
from pprint import pprint
import boto3
import argparse

# ------------ Textract helpers ------------

def get_rows_and_confidence(table_result, blocks_map):
    """
    Build two parallel maps:
      rows[row_idx][col_idx] -> cell text
      conf[row_idx][col_idx] -> cell confidence (float) or None
    """
    rows = {}
    conf = {}

    for rel in table_result.get('Relationships', []):
        if rel['Type'] != 'CHILD':
            continue
        for child_id in rel['Ids']:
            cell = blocks_map[child_id]
            if cell.get('BlockType') != 'CELL':
                continue

            r = cell['RowIndex']
            c = cell['ColumnIndex']

            if r not in rows:
                rows[r] = {}
                conf[r] = {}

            rows[r][c] = extract_text(cell, blocks_map)
            conf[r][c] = cell.get('Confidence')

    return rows, conf


def extract_text(cell_block, blocks_map):
    """Concatenate WORDs and mark selected checkboxes as 'X'. Trim trailing space."""
    parts = []
    for rel in cell_block.get('Relationships', []):
        if rel['Type'] != 'CHILD':
            continue
        for child_id in rel['Ids']:
            b = blocks_map[child_id]
            bt = b.get('BlockType')
            if bt == 'WORD':
                w = b.get('Text', '')
                # Quote numbers with commas so CSV stays valid
                if ',' in w and w.replace(',', '').isdigit():
                    parts.append(f'"{w}"')
                else:
                    parts.append(w)
            elif bt == 'SELECTION_ELEMENT' and b.get('SelectionStatus') == 'SELECTED':
                parts.append('X')
    return ' '.join(p for p in parts if p).strip()


def analyze_tables(file_path, region='us-east-1'):
    """Run Textract (TABLES) and return list of table blocks and the blocks map."""
    with open(file_path, 'rb') as f:
        content = f.read()

    client = boto3.client('textract', region_name=region)
    resp = client.analyze_document(
        Document={'Bytes': bytearray(content)},
        FeatureTypes=['TABLES']
    )

    blocks = resp.get('Blocks', [])
    blocks_map = {b['Id']: b for b in blocks}
    table_blocks = [b for b in blocks if b.get('BlockType') == 'TABLE']
    return table_blocks, blocks_map


# ------------ CSV builders ------------

def build_csvs_for_table(table_block, blocks_map, table_index):
    """
    Returns a tuple of two strings:
      (table_text_csv, table_confidence_csv)
    Both include a "Table: Table_i" header line.
    """
    rows_map, conf_map = get_rows_and_confidence(table_block, blocks_map)

    if not rows_map:
        header = f"Table: Table_{table_index}"
        return header, header

    row_indices = sorted(rows_map.keys())
    col_set = set()
    for r in row_indices:
        col_set.update(rows_map[r].keys())
    col_indices = sorted(col_set)

    # Build text CSV lines
    text_lines = [f"Table: Table_{table_index}"]
    for r in row_indices:
        row_cells = []
        for c in col_indices:
            cell = rows_map.get(r, {}).get(c, "")
            row_cells.append(cell)
        text_lines.append(",".join(row_cells))

    conf_lines = [f"Table: Table_{table_index}"]
    for r in row_indices:
        row_scores = []
        for c in col_indices:
            val = conf_map.get(r, {}).get(c, "")
            if isinstance(val, (int, float)):
                row_scores.append(f"{val:.2f}")
            else:
                row_scores.append("")
        conf_lines.append(",".join(row_scores))

    text_csv = "\n".join(line.rstrip() for line in text_lines if line.strip() != "")
    conf_csv = "\n".join(line.rstrip() for line in conf_lines if line.strip() != "")

    return text_csv, conf_csv


def build_all_csvs(file_path):
    
    table_blocks, blocks_map = analyze_tables(file_path)
    if not table_blocks:
        return "NO TABLE FOUND", "NO TABLE FOUND"

    all_text = []
    all_conf = []
    for i, tbl in enumerate(table_blocks, 1):
        text_csv, conf_csv = build_csvs_for_table(tbl, blocks_map, i)
        all_text.append(text_csv)
        all_conf.append(conf_csv)

    tables_csv = "\n".join(all_text)
    confidences_csv = "\n".join(all_conf)

    tables_csv = "\n".join([ln for ln in tables_csv.splitlines() if ln.strip() != ""])
    confidences_csv = "\n".join([ln for ln in confidences_csv.splitlines() if ln.strip() != ""])

    return tables_csv, confidences_csv


# ------------ Writer ------------

def write_csv(path, text):
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = [ln for ln in text.split("\n")]
    normalized = "\r\n".join(lines)
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        f.write(normalized)


# ------------ CLI ------------

import re
def sort_by_ending_number(string_list):
    """
    Sorts a list of strings by the numerical value at the end of each string.
    Assumes the number is the last sequence of digits in the string.
    """
    def get_ending_number(s):
        # Use regex to find all digits at the end of the string
        match = re.search(r'(\d+)$', s)
        if match:
            return int(match.group(1))
        return 0 # Default to 0 if no number is found, or handle as needed

    return sorted(string_list, key=get_ending_number)

def main(input_folder):
    output_folder = f"{input_folder}_output"
    os.makedirs(output_folder, exist_ok=True)
    for file in os.listdir(input_folder):
        file_with_path = os.path.join(input_folder, file)

        tables_csv, confidences_csv = build_all_csvs(file_with_path)

        base = os.path.splitext(os.path.basename(file_with_path))[0]
        out_tables = f"{base}_tables.csv"
        out_conf   = f"{base}_confidences.csv"

        write_csv(f"{output_folder}/{out_tables}", tables_csv)
        write_csv(f"{output_folder}/{out_conf}", confidences_csv)

        print("Wrote:")
        print("  ", os.path.abspath(f"{output_folder}/{out_tables}"))
        print("  ", os.path.abspath(f"{output_folder}/{out_conf}"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="AWS_Python_Table_Extraction",
        description="Extract tables from PDFs using AWS Textract."
    )
    parser.add_argument("input_folder", help="Path to folder containing the input PDF files.")
    args = parser.parse_args()

    main(args.input_folder)
