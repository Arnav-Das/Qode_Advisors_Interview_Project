-- ============================================================
-- F&O Analytics Queries
-- ============================================================

-- Q1: Top 10 symbols by OI change across exchanges
SELECT
    i.symbol,
    e.exchange_code,
    SUM(t.chg_in_oi) AS total_oi_change
FROM trades t
JOIN instruments i USING (instrument_id)
JOIN exchanges  e USING (exchange_id)
GROUP BY i.symbol, e.exchange_code
ORDER BY total_oi_change DESC
LIMIT 10;

-- Q2: 7-day rolling std dev of close prices for NIFTY options
SELECT
    t.timestamp,
    i.symbol,
    ex.expiry_dt,
    t.close_pr,
    STDDEV(t.close_pr) OVER (
        PARTITION BY i.symbol
        ORDER BY t.timestamp
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_stddev
FROM trades t
JOIN instruments i USING (instrument_id)
JOIN expiries   ex USING (expiry_id)
WHERE i.symbol = 'NIFTY'
  AND i.instrument_type IN ('OPTIDX')
ORDER BY t.timestamp;

-- Q3: Cross-exchange comparison: avg settle_pr gold futures (MCX) vs equity index futures (NSE)
SELECT
    e.exchange_code,
    i.instrument_type,
    AVG(t.settle_pr) AS avg_settle_price
FROM trades t
JOIN instruments i USING (instrument_id)
JOIN exchanges  e USING (exchange_id)
WHERE (e.exchange_code = 'MCX' AND i.symbol ILIKE '%GOLD%'  AND i.instrument_type = 'FUTSTK')
   OR (e.exchange_code = 'NSE' AND i.symbol IN ('NIFTY','BANKNIFTY') AND i.instrument_type = 'FUTIDX')
GROUP BY e.exchange_code, i.instrument_type
ORDER BY e.exchange_code;

-- Q4: Option chain summary grouped by expiry_dt and strike_pr
SELECT
    ex.expiry_dt,
    ex.strike_pr,
    ex.option_typ,
    SUM(t.contracts) AS total_volume,
    SUM(t.open_int)  AS total_oi,
    AVG(t.close_pr)  AS avg_close
FROM trades t
JOIN expiries ex USING (expiry_id)
JOIN instruments i USING (instrument_id)
WHERE i.symbol = 'NIFTY'
GROUP BY ex.expiry_dt, ex.strike_pr, ex.option_typ
ORDER BY ex.expiry_dt, ex.strike_pr;

-- Q5: Max volume in last 30 days using window function (performance-optimized)
WITH ranked AS (
    SELECT
        i.symbol,
        e.exchange_code,
        t.timestamp,
        t.contracts,
        MAX(t.contracts) OVER (
            PARTITION BY i.symbol, e.exchange_code
        ) AS max_volume
    FROM trades t
    JOIN instruments i USING (instrument_id)
    JOIN exchanges  e USING (exchange_id)
    WHERE t.timestamp >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT DISTINCT symbol, exchange_code, max_volume
FROM ranked
ORDER BY max_volume DESC;

-- Q6: EXPLAIN ANALYZE for post-optimization audit (Q5 base)
EXPLAIN ANALYZE
SELECT i.symbol, SUM(t.contracts) AS total_volume
FROM trades t
JOIN instruments i USING (instrument_id)
WHERE t.timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY i.symbol
ORDER BY total_volume DESC;

-- Q7: Daily OI build-up trend for BANKNIFTY CE options
SELECT
    t.timestamp,
    ex.strike_pr,
    SUM(t.open_int)  AS total_oi,
    SUM(t.chg_in_oi) AS daily_oi_change
FROM trades t
JOIN instruments i  USING (instrument_id)
JOIN expiries   ex  USING (expiry_id)
WHERE i.symbol = 'BANKNIFTY'
  AND ex.option_typ = 'CE'
GROUP BY t.timestamp, ex.strike_pr
ORDER BY t.timestamp, ex.strike_pr;
