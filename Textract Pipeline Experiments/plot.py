import pandas as pd
import matplotlib.pyplot as plt

def plot_diseases(file_path,
                  time_col="Row",
                  disease1="Chickenpox",
                  disease2="Mumps"):

    df = pd.read_csv(file_path)

    # Remove extra empty column from trailing commas
    df = df.loc[:, ~df.columns.str.contains("^Unnamed")]

    # Convert columns to numeric
    df[time_col] = pd.to_numeric(df[time_col], errors="coerce")
    df[disease1] = pd.to_numeric(df[disease1], errors="coerce")
    df[disease2] = pd.to_numeric(df[disease2], errors="coerce")

    print(df.head())
    print(df.columns)
    print(df["Row"].max())

    # Drop rows where Row is missing
    df = df.dropna(subset=[time_col])

    # Sort properly
    df = df.sort_values(time_col)

    plt.figure(figsize=(10,6))

    plt.plot(df[time_col], df[disease1], label=disease1, color="orange")
    plt.plot(df[time_col], df[disease2], label=disease2, color="green")

    plt.xlabel("Week Index")
    plt.ylabel("Cases")
    plt.title(f"{disease1} vs {disease2} (Textract)")
    plt.legend()

    plt.show()

plot_diseases(
    "1956-1958_textract_timeseries_hardcoded.csv",
    disease1="Chickenpox",
    disease2="Mumps"
)

