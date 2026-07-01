-- ============================================
-- MeridianMart Data Pipeline
-- Week 2 Day 3: Build Fact Table
-- Joins staging.transactions to all dims
-- unit_price_ghs pulled from dim_products
-- total_amount_ghs = quantity × unit_price_ghs
-- ============================================

-- ============================================
-- Create fact_transactions table
-- ============================================
CREATE TABLE IF NOT EXISTS marts.fact_transactions (
    transaction_key     SERIAL PRIMARY KEY,
    receipt_no          TEXT NOT NULL,
    transaction_date    TIMESTAMP NOT NULL,
    store_id            TEXT NOT NULL,
    staff_name          TEXT NOT NULL,
    customer_phone      TEXT,
    product_name        TEXT NOT NULL,
    category            TEXT NOT NULL,
    quantity            INTEGER NOT NULL,
    unit_price_ghs      NUMERIC(10, 2) NOT NULL,
    total_amount_ghs    NUMERIC(10, 2) NOT NULL,
    payment_method      TEXT NOT NULL,
    source_sheet        TEXT NOT NULL,

    -- Foreign keys to dimension tables
    store_key           INTEGER REFERENCES marts.dim_stores(store_key),
    staff_key           INTEGER REFERENCES marts.dim_staff(staff_key),
    product_key         INTEGER REFERENCES marts.dim_products(product_key),
    date_key            INTEGER REFERENCES marts.dim_date(date_key)
);

-- Clear before reload
TRUNCATE TABLE marts.fact_transactions RESTART IDENTITY CASCADE;

-- ============================================
-- INSERT into fact_transactions
-- Joins staging.transactions to all dims
-- Excludes rows flagged in audit.validation_log
-- ============================================
INSERT INTO marts.fact_transactions (
    receipt_no,
    transaction_date,
    store_id,
    staff_name,
    customer_phone,
    product_name,
    category,
    quantity,
    unit_price_ghs,
    total_amount_ghs,
    payment_method,
    source_sheet,
    store_key,
    staff_key,
    product_key,
    date_key
)
SELECT
    t.receipt_no,
    t.transaction_date,
    t.store_id,
    t.staff_name,
    NULLIF(TRIM(t.customer_phone), '')      AS customer_phone,
    dp.product_name,
    dp.category,
    t.quantity,
    dp.unit_price_ghs,
    t.quantity * dp.unit_price_ghs          AS total_amount_ghs,
    t.payment_method,
    t.source_sheet,
    ds.store_key,
    dst.staff_key,
    dp.product_key,
    dd.date_key
FROM staging.transactions t

-- Join to dim_products on product name
JOIN marts.dim_products dp
    ON TRIM(LOWER(t.product_sold)) = TRIM(LOWER(dp.product_name))

-- Join to dim_stores on store_id
JOIN marts.dim_stores ds
    ON TRIM(t.store_id) = TRIM(ds.store_id)

-- Join to dim_staff on full name + store
JOIN marts.dim_staff dst
    ON TRIM(LOWER(t.staff_name)) = TRIM(LOWER(dst.full_name))
    AND TRIM(t.store_id) = TRIM(dst.store_id)

-- Join to dim_date on transaction date
JOIN marts.dim_date dd
    ON t.transaction_date::DATE = dd.full_date

-- Exclude rows flagged in audit.validation_log
WHERE NOT EXISTS (
    SELECT 1
    FROM audit.validation_log vl
    WHERE vl.raw_value = t.receipt_no
      AND vl.check_name = 'duplicate_receipt_no'
);

-- Verify row count
SELECT 'fact_transactions' AS table_name, COUNT(*) AS rows
FROM marts.fact_transactions;

-- Verify all 11 stores represented
SELECT
    store_id,
    COUNT(*) AS transaction_rows
FROM marts.fact_transactions
GROUP BY store_id
ORDER BY store_id;

