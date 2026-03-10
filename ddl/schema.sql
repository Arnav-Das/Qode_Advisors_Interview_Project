-- F&O Multi-Exchange Database Schema

-- Exchanges
CREATE TABLE exchanges (
    exchange_id   SERIAL PRIMARY KEY,
    exchange_code VARCHAR(10) NOT NULL UNIQUE,  -- 'NSE', 'BSE', 'MCX'
    exchange_name VARCHAR(100) NOT NULL,
    country       VARCHAR(50) DEFAULT 'India'
);

-- Instruments
CREATE TABLE instruments (
    instrument_id   SERIAL PRIMARY KEY,
    exchange_id     INT NOT NULL REFERENCES exchanges(exchange_id),
    symbol          VARCHAR(30) NOT NULL,
    instrument_type VARCHAR(20) NOT NULL,        -- 'FUTSTK', 'OPTSTK', 'FUTIDX', 'OPTIDX'
    series          VARCHAR(10),
    UNIQUE (exchange_id, symbol, instrument_type)
);

-- Expiries
CREATE TABLE expiries (
    expiry_id  SERIAL PRIMARY KEY,
    expiry_dt  DATE NOT NULL,
    strike_pr  NUMERIC(12, 2),
    option_typ CHAR(2),                          -- 'CE', 'PE', NULL for futures
    UNIQUE (expiry_dt, strike_pr, option_typ)
);

-- Trades (partitioned by expiry_dt year-month)
CREATE TABLE trades (
    trade_id      BIGSERIAL,
    instrument_id INT  NOT NULL REFERENCES instruments(instrument_id),
    expiry_id     INT  NOT NULL REFERENCES expiries(expiry_id),
    timestamp     DATE NOT NULL,
    open_pr       NUMERIC(12, 2),
    high_pr       NUMERIC(12, 2),
    low_pr        NUMERIC(12, 2),
    close_pr      NUMERIC(12, 2),
    settle_pr     NUMERIC(12, 2),
    contracts     BIGINT,
    val_inlakh    NUMERIC(18, 4),
    open_int      BIGINT,
    chg_in_oi     BIGINT,
    PRIMARY KEY (trade_id, timestamp)
) PARTITION BY RANGE (timestamp);

-- Monthly partitions (example: 3 months)
CREATE TABLE trades_2023_01 PARTITION OF trades
    FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');
CREATE TABLE trades_2023_02 PARTITION OF trades
    FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');
CREATE TABLE trades_2023_03 PARTITION OF trades
    FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');

-- Indexes 
CREATE INDEX idx_trades_timestamp    ON trades (timestamp);
CREATE INDEX idx_trades_instrument   ON trades (instrument_id);
CREATE INDEX idx_instruments_symbol  ON instruments (symbol);
CREATE INDEX idx_instruments_exchange ON instruments (exchange_id);
CREATE INDEX idx_trades_ts_brin      ON trades USING BRIN (timestamp);
