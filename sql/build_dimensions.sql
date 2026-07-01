-- ============================================
-- MeridianMart Data Pipeline
-- Week 2 Day 2: Build Dimension Tables
-- Promotes data from staging → marts schema
-- Updated: removed Excel date conversion
-- (already handled in load_staging.sql)
-- ============================================

CREATE SCHEMA IF NOT EXISTS marts;

-- ============================================
-- Clear existing dimension data before reload
-- Safe to re-run multiple times
-- ============================================
TRUNCATE TABLE marts.dim_stores   RESTART IDENTITY CASCADE;
TRUNCATE TABLE marts.dim_staff    RESTART IDENTITY CASCADE;
TRUNCATE TABLE marts.dim_managers RESTART IDENTITY CASCADE;
TRUNCATE TABLE marts.dim_products RESTART IDENTITY CASCADE;

-- ============================================
-- dim_stores
-- 11 stores across 3 regions in Ghana
-- Expected: 11 rows
-- ============================================

CREATE TABLE IF NOT EXISTS marts.dim_stores (
    store_key     SERIAL PRIMARY KEY,
    store_id      TEXT NOT NULL UNIQUE,
    city          TEXT NOT NULL,
    region        TEXT NOT NULL
);

INSERT INTO marts.dim_stores (
    store_id,
    city,
    region
)
SELECT
    store_id,
    city,
    region
FROM staging.stores
ORDER BY store_id;

SELECT 'dim_stores' AS table_name, COUNT(*) AS rows
FROM marts.dim_stores;

-- ============================================
-- dim_staff
-- 90 employees across 11 stores
-- Expected: 90 rows
-- Note: date_hired already DATE type in staging
-- ============================================

CREATE TABLE IF NOT EXISTS marts.dim_staff (
    staff_key           SERIAL PRIMARY KEY,
    staff_id            TEXT NOT NULL UNIQUE,
    full_name           TEXT NOT NULL,
    role                TEXT NOT NULL,
    store_id            TEXT NOT NULL,
    phone_number        TEXT,
    date_hired          DATE,
    employment_status   TEXT NOT NULL
);

INSERT INTO marts.dim_staff (
    staff_id,
    full_name,
    role,
    store_id,
    phone_number,
    date_hired,
    employment_status
)
SELECT
    staff_id,
    full_name,
    role,
    store_id,
    phone_number,
    date_hired,
    employment_status
FROM staging.staff
ORDER BY staff_id;

SELECT 'dim_staff' AS table_name, COUNT(*) AS rows
FROM marts.dim_staff;

-- ============================================
-- dim_managers
-- 25 managers (11 store, 11 assistant, 3 regional)
-- Expected: 25 rows
-- Note: date_appointed already DATE type in staging
-- ============================================

CREATE TABLE IF NOT EXISTS marts.dim_managers (
    manager_key     SERIAL PRIMARY KEY,
    manager_id      TEXT NOT NULL UNIQUE,
    full_name       TEXT NOT NULL,
    role            TEXT NOT NULL,
    store_id        TEXT NOT NULL,
    phone_number    TEXT,
    email           TEXT,
    date_appointed  DATE,
    reports_to      TEXT
);

INSERT INTO marts.dim_managers (
    manager_id,
    full_name,
    role,
    store_id,
    phone_number,
    email,
    date_appointed,
    reports_to
)
SELECT
    manager_id,
    full_name,
    role,
    store_id,
    phone_number,
    email,
    date_appointed,
    reports_to
FROM staging.managers
ORDER BY manager_id;

SELECT 'dim_managers' AS table_name, COUNT(*) AS rows
FROM marts.dim_managers;

-- ============================================
-- dim_products
-- 65 products across 15 categories
-- Expected: 65 rows
-- ============================================

CREATE TABLE IF NOT EXISTS marts.dim_products (
    product_key     SERIAL PRIMARY KEY,
    product_id      TEXT NOT NULL UNIQUE,
    product_name    TEXT NOT NULL,
    category        TEXT NOT NULL,
    unit_price_ghs  NUMERIC(10, 2) NOT NULL
);

INSERT INTO marts.dim_products (
    product_id,
    product_name,
    category,
    unit_price_ghs
)
SELECT
    product_id,
    product_name,
    category,
    CAST(unit_price_ghs AS NUMERIC(10, 2))
FROM staging.products
ORDER BY product_id;

SELECT 'dim_products' AS table_name, COUNT(*) AS rows
FROM marts.dim_products;

-- ============================================
-- dim_date
-- Generated date spine — full 2026 calendar year
-- Expected: 365 rows
-- Uses generate_series() — no source table needed
-- ON CONFLICT ensures safe re-runs
-- ============================================

CREATE TABLE IF NOT EXISTS marts.dim_date (
    date_key        SERIAL PRIMARY KEY,
    full_date       DATE NOT NULL UNIQUE,
    day_of_week     TEXT NOT NULL,
    day_num         INTEGER NOT NULL,
    month_num       INTEGER NOT NULL,
    month_name      TEXT NOT NULL,
    quarter         INTEGER NOT NULL,
    year            INTEGER NOT NULL,
    is_weekend      BOOLEAN NOT NULL
);

INSERT INTO marts.dim_date (
    full_date,
    day_of_week,
    day_num,
    month_num,
    month_name,
    quarter,
    year,
    is_weekend
)
SELECT
    d::DATE                             AS full_date,
    TO_CHAR(d, 'Day')                   AS day_of_week,
    EXTRACT(DAY     FROM d)::INTEGER    AS day_num,
    EXTRACT(MONTH   FROM d)::INTEGER    AS month_num,
    TO_CHAR(d, 'Month')                 AS month_name,
    EXTRACT(QUARTER FROM d)::INTEGER    AS quarter,
    EXTRACT(YEAR    FROM d)::INTEGER    AS year,
    EXTRACT(DOW     FROM d) IN (0, 6)  AS is_weekend
FROM generate_series(
    '2026-01-01'::DATE,
    '2026-12-31'::DATE,
    '1 day'::INTERVAL
) AS d
ON CONFLICT (full_date) DO NOTHING;

SELECT 'dim_date' AS table_name, COUNT(*) AS rows
FROM marts.dim_date;

-- ============================================
-- Final verification — all 5 dimension counts
-- Expected:
--   dim_date      → 365
--   dim_managers  →  25
--   dim_products  →  65
--   dim_staff     →  90
--   dim_stores    →  11
-- ============================================
SELECT 'dim_stores'   AS table_name, COUNT(*) AS rows FROM marts.dim_stores
UNION ALL
SELECT 'dim_staff'    AS table_name, COUNT(*) AS rows FROM marts.dim_staff
UNION ALL
SELECT 'dim_managers' AS table_name, COUNT(*) AS rows FROM marts.dim_managers
UNION ALL
SELECT 'dim_products' AS table_name, COUNT(*) AS rows FROM marts.dim_products
UNION ALL
SELECT 'dim_date'     AS table_name, COUNT(*) AS rows FROM marts.dim_date
ORDER BY table_name;

