-- ============================================
-- MeridianMart Data Pipeline
-- Week 2 Day 3: Build dim_customers
-- Derived from fact_transactions
-- Deduplicates on customer_phone
-- ============================================

CREATE TABLE IF NOT EXISTS marts.dim_customers (
    customer_key        SERIAL PRIMARY KEY,
    customer_phone      TEXT UNIQUE,
    first_seen_date     DATE,
    total_visits        INTEGER
);

-- Clear before reload
TRUNCATE TABLE marts.dim_customers RESTART IDENTITY CASCADE;

-- Insert distinct customers from fact table
INSERT INTO marts.dim_customers (
    customer_phone,
    first_seen_date,
    total_visits
)
SELECT
    customer_phone,
    MIN(transaction_date::DATE)             AS first_seen_date,
    COUNT(DISTINCT receipt_no)              AS total_visits
FROM marts.fact_transactions
WHERE customer_phone IS NOT NULL
  AND customer_phone != ''
GROUP BY customer_phone
ORDER BY customer_phone;

-- Verify
SELECT 'dim_customers' AS table_name, COUNT(*) AS rows
FROM marts.dim_customers;

-- Sample output
SELECT
    customer_phone,
    first_seen_date,
    total_visits
FROM marts.dim_customers
ORDER BY total_visits DESC
LIMIT 5;

