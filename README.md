# Google Trend Archive: Global Real-Time Search Trends (2024–2026)

> **Dataset on Hugging Face:** [aurman/GoogleTrendArchive](https://huggingface.co/datasets/aurman/GoogleTrendArchive)  
> **DOI:** [10.57967/hf/7531](https://doi.org/10.57967/hf/7531)  
> **License:** CC-BY-4.0

A comprehensive archive of **7.6 million+ trending search instances** from Google's Trending Now feature, collected continuously from **November 28, 2024 to January 3, 2026** across 200+ countries and regions.

Unlike aggregated retrospective tools like Google Trends, *Trending Now* captures search queries experiencing **real-time surges**, offering unprecedented temporal granularity for studying collective attention dynamics.

---

## Contents

| File | Description |
|------|-------------|
| `load_data_demo.py` | Python demo: download and explore the dataset |
| `load_data_demo.ipynb` | Jupyter notebook version of the demo |
| `Processing_CleanedUp_Commented.R` | R script for preprocessing the raw daily CSV files |
| `Datasheet_GoogleTrendArchive.pdf` | Dataset datasheet (methodology, limitations, etc.) |

The actual data files (`daily_compressed.zip`, `googletrendarchive_preprocessed.csv`, `Trends_LocationList.csv`) are hosted on Hugging Face due to their size (1.5 GB+).

---

## Dataset at a Glance

| Property | Value |
|----------|-------|
| Total instances | 7,600,000+ trending searches |
| Temporal coverage | Nov 28, 2024 – Jan 3, 2026 |
| Geographic coverage | 1,358 countries and regions |
| Missing data | ~14 days (technical collection gaps) |
| Format | CSV (UTF-8) |

### Fields per instance

| Field | Description | Example |
|-------|-------------|---------|
| `Trends` | Search query / cluster label | `"man united vs bodø/glimt"` |
| `Search volume` | Bucketed traffic range | `"50K+"` |
| `Started` | Trend emergence timestamp (ISO) | `"2024-12-01T14:23:00+00:00"` |
| `Ended` | Trend end timestamp (ISO) | `"2024-12-01T16:45:00+00:00"` |
| `Trend breakdown` | Related query variations (comma-separated) | `"man utd vs bodo, man united bodo glimt"` |
| `Explore link` | Google Trends URL for this trend | `"https://trends.google.com/..."` |

---

## Quick Start

### Python

```bash
pip install datasets pandas
```

```python
from datasets import load_dataset

ds = load_dataset("aurman/GoogleTrendArchive", split="train", streaming=True)

for row in ds.take(5):
    print(row)
```

See [`load_data_demo.py`](load_data_demo.py) or [`load_data_demo.ipynb`](load_data_demo.ipynb) for a full walkthrough including filtering by country, parsing timestamps, and plotting trend durations.

### R

```r
# Install once
install.packages(c("data.table", "lubridate", "ggplot2"))
```

See [`Processing_CleanedUp_Commented.R`](Processing_CleanedUp_Commented.R) for the full preprocessing pipeline used to generate `googletrendarchive_preprocessed.csv` from the raw daily files.

---
---
## Original Data Collection

See [`trendsccraper_public.py`](trendsccraper_public.py) for the Python Playwright implementation of the original scraping code used to collect the raw daily files.

---
## Use Cases

- **Information Diffusion** — track how topics cascade across regions
- **Event Detection** — identify breaking news and crises from search surges
- **Comparative Cultural Studies** — analyze collective attention across countries
- **Crisis Communication** — understand information needs during emergencies
- **Temporal Pattern Analysis** — daily, weekly, and seasonal rhythms
- **Predictive Modeling** — forecast trend emergence, duration, and spread
- **Media Ecosystem Analysis** — compare search trends with news/social media

---

## Limitations

- Search volumes are **bucketed**, not exact counts
- Google's trend algorithm is **proprietary** (clustering decisions are opaque)
- ~14 days of **missing data** due to collection outages
- Trends represent **relative surges**, not absolute search volume
- **Digital divide**: internet penetration varies widely across regions

---

## Citation

```bibtex
@dataset{urman2026googletrendarchive,
  title   = {Google Trend Archive: Global Real-Time Search Trends},
  author  = {Urman, Aleksandra and Hann{\'a}k, Anik{\'o} and Baumann, Joachim},
  year    = {2026},
  publisher = {Hugging Face},
  doi     = {10.57967/hf/7531},
  url     = {https://huggingface.co/datasets/aurman/GoogleTrendArchive}
}
```

---

## Authors

**Aleksandra Urman, Anikó Hannák, Joachim Baumann**  
Social Computing Group, University of Zurich & Stanford Artificial Intelligence Laboratory  
Contact: [urman@ifi.uzh.ch](mailto:urman@ifi.uzh.ch)

### Funding

- Swiss National Science Foundation – PostDoc Mobility fellowship P500-2 235328 (JB)
- SNSF Project Grant 215354 (AU and AH)
