import duckdb
import pandas as pd

DB_PATH  = "fno_data.duckdb"
CSV_PATH = "nse_fo_3m.csv"   # Kaggle dataset CSV

con = duckdb.connect(DB_PATH)

con.execute("""
CREATE TABLE IF NOT EXISTS exchanges (
    exchange_id   INTEGER PRIMARY KEY,
    exchange_code VARCHAR(10) UNIQUE,
    exchange_name VARCHAR(100)
);
INSERT OR IGNORE INTO exchanges VALUES
    (1, 'NSE', 'National Stock Exchange'),
    (2, 'BSE', 'Bombay Stock Exchange'),
    (3, 'MCX', 'Multi Commodity Exchange');
""")

con.execute("""
CREATE TABLE IF NOT EXISTS instruments (
    instrument_id   INTEGER PRIMARY KEY,
    exchange_id     INTEGER,
    symbol          VARCHAR(30),
    instrument_type VARCHAR(20),
    series          VARCHAR(10)
);
""")

con.execute("""
CREATE TABLE IF NOT EXISTS expiries (
    expiry_id  INTEGER PRIMARY KEY,
    expiry_dt  DATE,
    strike_pr  DOUBLE,
    option_typ VARCHAR(2)
);
""")

con.execute("""
CREATE TABLE IF NOT EXISTS trades (
    trade_id      INTEGER,
    instrument_id INTEGER,
    expiry_id     INTEGER,
    timestamp     DATE,
    open_pr       DOUBLE,
    high_pr       DOUBLE,
    low_pr        DOUBLE,
    close_pr      DOUBLE,
    settle_pr     DOUBLE,
    contracts     BIGINT,
    val_inlakh    DOUBLE,
    open_int      BIGINT,
    chg_in_oi     BIGINT
);
""")

print("Loading CSV...")
df = pd.read_csv(CSV_PATH, parse_dates=["TIMESTAMP", "EXPIRY_DT"])
df.columns = [c.lower() for c in df.columns]
print(f"Rows loaded: {len(df):,}")

# Populate instruments 
instr = df[["symbol", "instrument"]].drop_duplicates().reset_index(drop=True)
instr["instrument_id"] = instr.index + 1
instr["exchange_id"]   = 1  # NSE default; extend for BSE/MCX
instr["series"]        = None
instr = instr.rename(columns={"instrument": "instrument_type"})
con.execute("INSERT INTO instruments SELECT instrument_id, exchange_id, symbol, instrument_type, series FROM instr")

# Populate expiries 
exp = df[["expiry_dt", "strike_pr", "option_typ"]].drop_duplicates().reset_index(drop=True)
exp["expiry_id"] = exp.index + 1
con.execute("INSERT INTO expiries SELECT expiry_id, expiry_dt, strike_pr, option_typ FROM exp")

# Populate trades 
trades = df.merge(instr[["symbol","instrument_type","instrument_id"]], left_on=["symbol","instrument"], right_on=["symbol","instrument_type"])
trades = trades.merge(exp[["expiry_dt","strike_pr","option_typ","expiry_id"]], on=["expiry_dt","strike_pr","option_typ"])
trades["trade_id"] = range(1, len(trades)+1)
trades_final = trades[["trade_id","instrument_id","expiry_id","timestamp","open","high","low","close","settle_pr","contracts","val_inlakh","open_int","chg_in_oi"]]
trades_final.columns = ["trade_id","instrument_id","expiry_id","timestamp","open_pr","high_pr","low_pr","close_pr","settle_pr","contracts","val_inlakh","open_int","chg_in_oi"]
con.execute("INSERT INTO trades SELECT * FROM trades_final")

print("Data loaded successfully.")
print(con.execute("SELECT COUNT(*) FROM trades").fetchone())
con.close()
