-- ============================================
-- MeridianMart Data Pipeline
-- Week 2 Day 3: FK Integrity Checks
-- Counts fact rows with no match in each dim
-- All should return 0 orphans
-- ============================================

-- CHECK 1: fact rows with no matching store
SELECT
    'no_matching_store'     AS check_name,
    COUNT(*)                AS orphan_count
FROM marts.fact_transactions ft
LEFT JOIN marts.dim_stores ds
    ON ft.store_key = ds.store_key
WHERE ds.store_key IS NULL

UNION ALL

-- CHECK 2: fact rows with no matching staff
SELECT
    'no_matching_staff'     AS check_name,
    COUNT(*)                AS orphan_count
FROM marts.fact_transactions ft
LEFT JOIN marts.dim_staff dst
    ON ft.staff_key = dst.staff_key
WHERE dst.staff_key IS NULL

UNION ALL

-- CHECK 3: fact rows with no matching product
SELECT
    'no_matching_product'   AS check_name,
    COUNT(*)                AS orphan_count
FROM marts.fact_transactions ft
LEFT JOIN marts.dim_products dp
    ON ft.product_key = dp.product_key
WHERE dp.product_key IS NULL

UNION ALL

-- CHECK 4: fact rows with no matching date
SELECT
    'no_matching_date'      AS check_name,
    COUNT(*)                AS orphan_count
FROM marts.fact_transactions ft
LEFT JOIN marts.dim_date dd
    ON ft.date_key = dd.date_key
WHERE dd.date_key IS NULL

ORDER BY check_name;

