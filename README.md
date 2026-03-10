# F&O Multi-Exchange Database — Senior Data Associate Assignment

## Overview
Relational database design and SQL analytics for high-volume Futures & Options data
from NSE, BSE, and MCX. Uses 3NF normalization for data integrity and query efficiency.

## Schema Design Rationale

### Why 3NF over Star Schema?
A star schema denormalizes data for fast OLAP reads but introduces update anomalies
and redundancy — problematic for live trading data that is updated intraday.
3NF ensures each fact is stored once, reducing storage for 2.5M+ row datasets and
making incremental ingestion (HFT-style) clean and consistent.

### Table Structure
| Table       | Purpose                                         |
|-------------|------------------------------------------------|
| exchanges   | Exchange metadata (NSE, BSE, MCX)              |
| instruments | Unique trading symbols per exchange             |
| expiries    | Strike prices and expiry dates (shared)         |
| trades      | Daily OHLC, volume, OI — the core fact table   |

### Normalization Choices
- **Expiries** extracted as its own table to avoid repeating strike_pr/expiry_dt
  in every trade row — critical for option chains with hundreds of strikes.
- **Instruments** separated from trades to allow symbol-level metadata queries
  without scanning the massive trades table.
- **Exchanges** table enables clean cross-exchange joins and future additions
  (e.g., SGX Nifty).

## Scalability for 10M+ Rows / HFT Ingestion
- `trades` is **range-partitioned by timestamp** — queries on recent data scan
  only the relevant partition (e.g., last 30 days = 1 partition).
- **BRIN indexes** on `timestamp` are optimal for append-only time-series:
  tiny index size, fast range scans.
- **B-tree indexes** on `symbol` and `exchange_id` for join acceleration.
- For true HFT ingestion, recommend **TimescaleDB** (PostgreSQL extension) or
  **DuckDB** for analytical workloads — DuckDB can scan the Kaggle CSV directly
  without a full ETL load.

## Files
```
├── README.md
├── ddl/
│   └── schema.sql          # CREATE TABLE, INDEX, PARTITION
├── queries/
│   └── analytics_queries.sql  # 7 advanced SQL queries
├── notebook/
│   └── load_data.ipynb     # DuckDB CSV ingestion notebook
└── reasoning/
    └── design_reasoning.pdf # Design rationale document
```

## Dataset
[NSE F&O Dataset 3M — Kaggle](https://kaggle.com/datasets/sunnysai12345/nse-future-and-options-dataset-3m)
