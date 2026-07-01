-- ============================================
-- MeridianMart Data Pipeline
-- Week 2 Day 1: SQL Validation Checks
-- Logs findings to audit.validation_log
-- Run after extract_all.py completes
-- ============================================

-- Clear previous validation run first
TRUNCATE TABLE audit.validation_log;

-- ============================================
-- CHECK 1: Duplicate receipt numbers
-- Same receipt_no appearing more than once
-- across all stores
-- ============================================

INSERT INTO audit.validation_log (
    table_name,
    check_name,
    store_id,
    source_sheet,
    raw_value,
    flagged_at
)
SELECT
    'raw.transactions'          AS table_name,
    'duplicate_receipt_no'      AS check_name,
    store_id                    AS store_id,
    source_sheet                AS source_sheet,
    receipt_no                  AS raw_value,
    NOW()                       AS flagged_at
FROM raw.transactions
GROUP BY receipt_no, store_id, source_sheet
HAVING COUNT(*) > 3;

-- ============================================
-- CHECK 2: Product names in transactions
-- that don't match any product in Products Master
-- ============================================

INSERT INTO audit.validation_log (
    table_name,
    check_name,
    store_id,
    source_sheet,
    raw_value,
    flagged_at
)
SELECT DISTINCT
    'raw.transactions'              AS table_name,
    'unmatched_product_name'        AS check_name,
    t.store_id                      AS store_id,
    t.source_sheet                  AS source_sheet,
    t.product_sold                  AS raw_value,
    NOW()                           AS flagged_at
FROM raw.transactions t
LEFT JOIN raw.products p
    ON TRIM(LOWER(t.product_sold)) = TRIM(LOWER(p.product_name))
WHERE p.product_name IS NULL
  AND t.product_sold IS NOT NULL
  AND t.product_sold != '';

  -- ============================================
-- CHECK 3: Staff names in transactions
-- that don't match any staff in Staff Master
-- ============================================

INSERT INTO audit.validation_log (
    table_name,
    check_name,
    store_id,
    source_sheet,
    raw_value,
    flagged_at
)
SELECT DISTINCT
    'raw.transactions'              AS table_name,
    'unmatched_staff_name'          AS check_name,
    t.store_id                      AS store_id,
    t.source_sheet                  AS source_sheet,
    t.staff_name                    AS raw_value,
    NOW()                           AS flagged_at
FROM raw.transactions t
LEFT JOIN raw.staff s
    ON TRIM(LOWER(t.staff_name)) = TRIM(LOWER(s.full_name))
WHERE s.full_name IS NULL
  AND t.staff_name IS NOT NULL
  AND t.staff_name != '';

  -- ============================================
-- Summary: findings by check type
-- Run this after the INSERT checks above
-- ============================================

SELECT
    check_name,
    COUNT(*) AS findings
FROM audit.validation_log
GROUP BY check_name
ORDER BY findings DESC;

-- ============================================
-- MeridianMart Data Pipeline
-- Week 2 Day 1: SQL Validation Checks
-- ============================================

-- Clear previous run
TRUNCATE TABLE audit.validation_log;

-- ============================================
-- CHECK 1: Duplicate receipt numbers
-- ============================================
INSERT INTO audit.validation_log (
    table_name, check_name, store_id,
    source_sheet, raw_value, flagged_at
)
SELECT
    'raw.transactions'      AS table_name,
    'duplicate_receipt_no'  AS check_name,
    store_id,
    source_sheet,
    receipt_no              AS raw_value,
    NOW()                   AS flagged_at
FROM raw.transactions
GROUP BY receipt_no, store_id, source_sheet
HAVING COUNT(*) > 3;

-- ============================================
-- CHECK 2: Unmatched product names
-- ============================================
INSERT INTO audit.validation_log (
    table_name, check_name, store_id,
    source_sheet, raw_value, flagged_at
)
SELECT DISTINCT
    'raw.transactions'          AS table_name,
    'unmatched_product_name'    AS check_name,
    t.store_id,
    t.source_sheet,
    t.product_sold              AS raw_value,
    NOW()                       AS flagged_at
FROM raw.transactions t
LEFT JOIN raw.products p
    ON TRIM(LOWER(t.product_sold)) = TRIM(LOWER(p.product_name))
WHERE p.product_name IS NULL
  AND t.product_sold IS NOT NULL
  AND t.product_sold != '';

-- ============================================
-- CHECK 3: Unmatched staff names
-- ============================================
INSERT INTO audit.validation_log (
    table_name, check_name, store_id,
    source_sheet, raw_value, flagged_at
)
SELECT DISTINCT
    'raw.transactions'      AS table_name,
    'unmatched_staff_name'  AS check_name,
    t.store_id,
    t.source_sheet,
    t.staff_name            AS raw_value,
    NOW()                   AS flagged_at
FROM raw.transactions t
LEFT JOIN raw.staff s
    ON TRIM(LOWER(t.staff_name)) = TRIM(LOWER(s.full_name))
WHERE s.full_name IS NULL
  AND t.staff_name IS NOT NULL
  AND t.staff_name != '';

-- ============================================
-- Summary output
-- ============================================
SELECT
    check_name,
    COUNT(*) AS findings
FROM audit.validation_log
GROUP BY check_name
ORDER BY findings DESC;

