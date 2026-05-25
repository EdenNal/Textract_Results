# Extract each sheet of an XLSX file as a CSV file into a folder passed as argument
import os
import pandas as pd

def extract_csv_from_xlsx(xlsx_path, output_folder):
    # Load the Excel file
    xls = pd.ExcelFile(xlsx_path)
    csv_outputs = {}
    
    # Iterate through each sheet and convert to CSV
    for sheet_name in xls.sheet_names:
        base_name = os.path.basename(output_folder)
        sheet_number = xls.sheet_names.index(sheet_name) + 1
        csv_file_name = f"{base_name}_Part{sheet_number}.csv"
        df = pd.read_excel(xls, sheet_name=sheet_name)
        csv_data = df.to_csv(index=False)

        # Write the CSV data to a file
        csv_file_path = os.path.join(output_folder, csv_file_name)
        with open(csv_file_path, "w", encoding="utf-8") as f:
            f.write(csv_data)

    for sheet_name in xls.sheet_names:
        df = pd.read_excel(xls, sheet_name=sheet_name)
        csv_data = df.to_csv(index=False)
        csv_outputs[sheet_name] = csv_data
    
    return csv_outputs

# Use argparse for command line arguments
import argparse
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract CSV files from an XLSX file.")
    parser.add_argument("input_xlsx", help="Path to the input XLSX file.")
    args = parser.parse_args()

    output_dir = os.path.splitext(os.path.basename(args.input_xlsx))[0]
    os.makedirs(output_dir, exist_ok=True)
    extract_csv_from_xlsx(args.input_xlsx, output_dir)