

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

df = pd.read_csv("1956-1958_textract_timeseries_meningitis_measles.csv", index_col=0)

plt.figure()
plt.plot(df.index, df["Measles"], label="Measles")
plt.plot(df.index, df["Meningitis"], label="Meningitis")

plt.xlabel("Time")
plt.ylabel("Cases")
plt.title("Measles vs Meningitis (1956-1958) Textract Data -- no hardcoding")
plt.legend()
plt.show()

# import pandas as pd
# import matplotlib.pyplot as plt

# manual_path   = "1956-1958_manual_timeseries_meningitis_measles.csv"
# textract_path = "1956-1958_textract_hardcoded.csv"

# manual = pd.read_csv(manual_path)
# textract = pd.read_csv(textract_path)

# # --- Prefer aligning by a real key if it exists ---
# key_cols = None
# for candidate in [("Year", "Week"), ("year", "week"), ("file",), ("File",), ("Row",), ("row",)]:
#     if all(c in manual.columns for c in candidate) and all(c in textract.columns for c in candidate):
#         key_cols = list(candidate)
#         break

# if "Meningitis" not in manual.columns or "Meningitis" not in textract.columns:
#     raise ValueError(
#         f"Missing 'Meningitis' column.\n"
#         f"Manual columns: {list(manual.columns)}\n"
#         f"Textract columns: {list(textract.columns)}"
#     )

# if key_cols:
#     # Align by key (best)
#     m = manual[key_cols + ["Meningitis"]].copy()
#     t = textract[key_cols + ["Meningitis"]].copy()

#     m["Meningitis"] = pd.to_numeric(m["Meningitis"], errors="coerce")
#     t["Meningitis"] = pd.to_numeric(t["Meningitis"], errors="coerce")

#     aligned = m.merge(t, on=key_cols, how="inner", suffixes=("_Manual", "_Textract")).sort_values(key_cols)
#     x = range(1, len(aligned) + 1)
#     manual_series = aligned["Meningitis_Manual"].to_numpy()
#     textract_series = aligned["Meningitis_Textract"].to_numpy()
#     x_label = "Time"
# else:
#     # Fallback: align by row order (works only if rows already correspond)
#     m = pd.to_numeric(manual["Meningitis"], errors="coerce").to_numpy()
#     t = pd.to_numeric(textract["Meningitis"], errors="coerce").to_numpy()
#     n = min(len(m), len(t))
#     manual_series = m[:n]
#     textract_series = t[:n]
#     x = range(1, n + 1)
#     x_label = "Row (by order)"

# # --- Plot overlay ---
# plt.figure()
# plt.plot(list(x), manual_series, label="Manual")
# plt.plot(list(x), textract_series, label="Textract")
# plt.title("Meningitis: Manual vs Textract")
# plt.xlabel(x_label)
# plt.ylabel("Cases")
# plt.legend()
# plt.tight_layout()
# plt.show()

# --- Plot difference ---
# diff = manual_series - textract_series

# plt.figure()
# plt.axhline(0)
# plt.plot(list(x), diff)
# plt.title("Meningitis Difference (Manual − Textract)")
# plt.xlabel(x_label)
# plt.ylabel("Cases difference")
# plt.tight_layout()
# plt.show()


