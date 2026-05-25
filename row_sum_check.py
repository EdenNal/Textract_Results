import csv
import re

def to_int_or_none(value):
    """
    Try hard to convert a cell to int.
    Returns int or None.
    """
    if value is None:
        return None

    value = value.strip()

    # fast path
    try:
        return int(value)
    except ValueError:
        pass

    # remove commas (e.g. "1,629")
    cleaned = value.replace(",", "")
    try:
        return int(cleaned)
    except ValueError:
        return None


def check_row_sums_tables_only(
    csv_path,
    target_index=4,
    start_index=9,
    step=3
):
    results = []

    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)

        for row_num, row in enumerate(reader):

            if not row or not row[0].endswith("_tables.csv"):
                continue

            total = 0
            used_indices = []

            for i in range(start_index, len(row), step):
                val = to_int_or_none(row[i])
                if val is not None:
                    total += val
                    used_indices.append((i, val))

            target_val = (
                to_int_or_none(row[target_index])
                if target_index < len(row)
                else None
            )

            results.append({
                "row": row_num,
                "source": row[0],
                "value_at_4": target_val,
                "computed_sum": total,
                "matches": target_val == total if target_val is not None else False,
                "used_terms": used_indices
            })
    print(results)

    return results


#check_row_sums_tables_only('Textract Pipeline Experiments/by disease/1_reordered.csv')



def generate_tables_check_csv(
    input_csv_path,
    output_csv_path,
    target_index=3,  # index of the value we want to compare against the sum
    start_index=9,
    step=3,
    confidence_suffix="_tables.csv"
):
    """
    Creates a new CSV containing (for table rows only):
    source_file, value_at_index_4, computed_sum, values_used, matches

    values_used is a semicolon-separated list like: "9:9;12:4;15:25;21:182"
    meaning index:value for each numeric term included in the sum.
    """

    with open(input_csv_path, newline="", encoding="utf-8") as fin, \
         open(output_csv_path, "w", newline="", encoding="utf-8") as fout:

        reader = csv.reader(fin)
        writer = csv.writer(fout)

        # header
        writer.writerow(["source_file", "value_at_3", "computed_sum", "difference", "values_used", "matches"])

        for row_num, row in enumerate(reader):
            # only apply to confidence rows
            if not row or not row[0].endswith(confidence_suffix):
                continue

            source = row[0]

            # target value (index 4)
            target_val = to_int_or_none(row[target_index]) if target_index < len(row) else None

            # compute sum of indices 9,12,15,... skipping non-numeric
            total = 0
            used = []  # list of (index, value)

            for i in range(start_index, len(row), step):
                v = to_int_or_none(row[i])
                if v is not None and v!= 8:
                    total += v
                    used.append((i, v))

            values_used_str = ";".join(f"{i}:{v}" for i, v in used)

            matches = (target_val == total) if target_val is not None else False
            difference = target_val - total if target_val is not None else 0

            writer.writerow([source, target_val, total, difference, values_used_str, matches])

    return output_csv_path

#generate_tables_check_csv('Textract Pipeline Experiments/by disease/8_reordered.csv','measeles_tables_check.csv')



import csv
import matplotlib.pyplot as plt

def plot_difference_scatter(csv_path):
    """
    Reads a CSV with columns:
    source_file, value_at_4, computed_sum, values_used, matches

    Plots a scatterplot of:
    difference = value_at_4 - computed_sum
    """

    differences = []
    x = []

    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader):
            
            print(f"Processing row {i}: {row['source_file']}")
            print(f"Row {i}: value_at_3={row['value_at_3']}, computed_sum={row['computed_sum']}")
            try:
                
                diff = int(row["value_at_3"]) - int(row["computed_sum"])
                
                print(f"Row {i}: value_at_3={row['value_at_3']}, computed_sum={row['computed_sum']}, difference={diff}")
                x.append(i)
                differences.append(diff)
                

            except (ValueError, TypeError, KeyError):
                continue
            print(f"Row {i}: difference={diff}")

    print(f"Total points plotted: {len(differences)}")
    plt.figure()
    plt.scatter(x, differences)
    plt.axhline(0)  # reference line: perfect match
    plt.xlabel("Week of 1956")
    plt.ylabel("Difference between total and computed sum" )
    plt.title("Row-Sum Validation for the Chickenpox Epidemic of 1956 (Textract Data)")
    plt.show()
plot_difference_scatter("chickenpox_tables_check.csv")



