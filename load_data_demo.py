"""
Google Trend Archive – Python Data Loader Demo
===============================================
Dataset: https://huggingface.co/datasets/aurman/GoogleTrendArchive
DOI:     https://doi.org/10.57967/hf/7531

This script demonstrates how to:
  1. Load the dataset from Hugging Face (streaming or full)
  2. Filter by country / region
  3. Parse timestamps and compute trend durations
  4. Explore search volume distributions
  5. Find top trending queries for a given location

Requirements:
    pip install datasets pandas matplotlib
"""

import pandas as pd
from datasets import load_dataset


# ── 1. LOAD THE DATASET ──────────────────────────────────────────────────────

# Option A: Streaming (recommended for exploration — no full download needed)
print("Loading dataset in streaming mode...")
ds_stream = load_dataset(
    "aurman/GoogleTrendArchive",
    split="train",
    streaming=True,
)

# Preview the first 5 rows
print("\nFirst 5 rows (streaming):")
for i, row in enumerate(ds_stream.take(5)):
    print(f"  [{i}]", row)

# Option B: Full download into memory (~1.5 GB preprocessed CSV)
# Uncomment if you want the full dataset as a Pandas DataFrame:
#
# print("\nDownloading full dataset (this may take a few minutes)...")
# ds_full = load_dataset("aurman/GoogleTrendArchive", split="train")
# df = ds_full.to_pandas()
# print(f"Loaded {len(df):,} rows, columns: {list(df.columns)}")


# ── 2. LOAD AS PANDAS (from a local copy or direct CSV download) ─────────────
# If you downloaded googletrendarchive_preprocessed.csv from Hugging Face:
#
# df = pd.read_csv("googletrendarchive_preprocessed.csv", low_memory=False)

# For this demo we'll use a small in-memory sample built from the stream:
print("\nBuilding a sample DataFrame from the first 10,000 rows...")
sample_rows = list(ds_stream.take(10_000))
df = pd.DataFrame(sample_rows)

print(f"Sample shape: {df.shape}")
print(f"Columns: {list(df.columns)}")
print(df.head(3).to_string())


# ── 3. PARSE TIMESTAMPS & COMPUTE TREND DURATION ────────────────────────────

df["Started"] = pd.to_datetime(df["Started"], utc=True, errors="coerce")
df["Ended"]   = pd.to_datetime(df["Ended"],   utc=True, errors="coerce")
df["duration_minutes"] = (df["Ended"] - df["Started"]).dt.total_seconds() / 60

print("\nTrend duration summary (minutes):")
print(df["duration_minutes"].describe().round(1))


# ── 4. FILTER BY LOCATION ────────────────────────────────────────────────────
# The 'location' column uses ISO country / region codes (e.g. 'US', 'DE', 'US-CA')

TARGET_LOCATION = "US"
df_us = df[df["location"] == TARGET_LOCATION].copy()
print(f"\nRows for location '{TARGET_LOCATION}': {len(df_us):,}")


# ── 5. TOP TRENDING QUERIES ──────────────────────────────────────────────────

print(f"\nTop 10 most-frequent trending queries in '{TARGET_LOCATION}':")
top_queries = (
    df_us["Trends"]
    .value_counts()
    .head(10)
    .reset_index()
    .rename(columns={"index": "query", "Trends": "count"})
)
print(top_queries.to_string(index=False))


# ── 6. SEARCH VOLUME DISTRIBUTION ───────────────────────────────────────────

print("\nSearch volume bucket distribution:")
print(df["Search volume"].value_counts().head(10))


# ── 7. TRENDS OVER TIME ──────────────────────────────────────────────────────

import matplotlib.pyplot as plt

daily_counts = (
    df.dropna(subset=["Started"])
    .set_index("Started")
    .resample("D")
    .size()
    .rename("num_trends")
)

fig, ax = plt.subplots(figsize=(12, 4))
daily_counts.plot(ax=ax, linewidth=1.2, color="#e63946")
ax.set_title("Daily Trending Search Instances (sample)", fontsize=13)
ax.set_xlabel("Date")
ax.set_ylabel("Number of trends")
ax.grid(axis="y", alpha=0.3)
plt.tight_layout()
plt.savefig("trends_over_time.png", dpi=150)
print("\nPlot saved to trends_over_time.png")
plt.show()


# ── 8. DURATION HISTOGRAM ───────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(8, 4))
df["duration_minutes"].clip(upper=1440).hist(bins=50, ax=ax, color="#457b9d", edgecolor="white")
ax.set_title("Trend Duration Distribution (capped at 24 h)", fontsize=13)
ax.set_xlabel("Duration (minutes)")
ax.set_ylabel("Count")
plt.tight_layout()
plt.savefig("trend_duration_histogram.png", dpi=150)
print("Plot saved to trend_duration_histogram.png")
plt.show()
