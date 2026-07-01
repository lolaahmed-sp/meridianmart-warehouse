-- ============================================
-- MeridianMart Data Pipeline
-- Load Staging Tables from Raw
-- Promotes raw data → staging with type casting
-- ============================================

-- Clear staging tables before reload
TRUNCATE TABLE staging.stores   RESTART IDENTITY CASCADE;
TRUNCATE TABLE staging.staff    RESTART IDENTITY CASCADE;
TRUNCATE TABLE staging.managers RESTART IDENTITY CASCADE;
TRUNCATE TABLE staging.products RESTART IDENTITY CASCADE;

-- ============================================
-- Load staging.stores
-- ============================================
INSERT INTO staging.stores (
    store_id,
    city,
    region
)
SELECT
    TRIM(store_id),
    TRIM(city),
    TRIM(region)
FROM raw.stores
WHERE store_id IS NOT NULL
  AND store_id != '';

SELECT 'staging.stores' AS table_name, COUNT(*) AS rows
FROM staging.stores;

-- ============================================
-- Load staging.staff
-- ============================================
INSERT INTO staging.staff (
    staff_id,
    full_name,
    role,
    store_id,
    phone_number,
    date_hired,
    employment_status
)
SELECT
    TRIM(staff_id),
    TRIM(full_name),
    TRIM(role),
    TRIM(store_id),
    NULLIF(TRIM(phone_number), ''),
    CASE
        WHEN TRIM(date_hired) ~ '^\d+(\.\d+)?$'
        THEN TO_DATE('1899-12-30', 'YYYY-MM-DD')
             + CAST(CAST(TRIM(date_hired) AS FLOAT) AS INTEGER)
        ELSE NULL
    END,
    TRIM(employment_status)
FROM raw.staff
WHERE staff_id IS NOT NULL
  AND staff_id != ''
  AND TRIM(role) IN (
      'Cashier',
      'Sales Associate',
      'Stock Clerk',
      'Security'
  )
  AND TRIM(employment_status) IN ('Active', 'Inactive');

SELECT 'staging.staff' AS table_name, COUNT(*) AS rows
FROM staging.staff;

-- ============================================
-- Load staging.managers
-- ============================================
INSERT INTO staging.managers (
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
    TRIM(manager_id),
    TRIM(full_name),
    TRIM(role),
    TRIM(store_id),
    NULLIF(TRIM(phone_number), ''),
    NULLIF(TRIM(email), ''),
    CASE
        WHEN TRIM(date_appointed) ~ '^\d+(\.\d+)?$'
        THEN TO_DATE('1899-12-30', 'YYYY-MM-DD')
             + CAST(CAST(TRIM(date_appointed) AS FLOAT) AS INTEGER)
        ELSE NULL
    END,
    NULLIF(TRIM(reports_to), '')
FROM raw.managers
WHERE manager_id IS NOT NULL
  AND manager_id != ''
  AND TRIM(role) IN (
      'Store Manager',
      'Assistant Store Manager',
      'Regional Manager'
  );

SELECT 'staging.managers' AS table_name, COUNT(*) AS rows
FROM staging.managers;

-- ============================================
-- Load staging.products
-- ============================================
INSERT INTO staging.products (
    product_id,
    product_name,
    category,
    unit_price_ghs,
    updated_by
)
SELECT
    TRIM(product_id),
    TRIM(product_name),
    TRIM(category),
    CAST(TRIM(unit_price_ghs) AS NUMERIC(10,2)),
    NULLIF(TRIM(updated_by), '')
FROM raw.products
WHERE product_id  IS NOT NULL
  AND product_id  != ''
  AND unit_price_ghs IS NOT NULL
  AND unit_price_ghs != ''
  AND TRIM(unit_price_ghs) ~ '^\d+(\.\d+)?$';

SELECT 'staging.products' AS table_name, COUNT(*) AS rows
FROM staging.products;

-- ============================================
-- Final verification
-- ============================================
SELECT 'staging.stores'   AS table_name, COUNT(*) AS rows FROM staging.stores
UNION ALL
SELECT 'staging.staff'    AS table_name, COUNT(*) AS rows FROM staging.staff
UNION ALL
SELECT 'staging.managers' AS table_name, COUNT(*) AS rows FROM staging.managers
UNION ALL
SELECT 'staging.products' AS table_name, COUNT(*) AS rows FROM staging.products
ORDER BY table_name;

