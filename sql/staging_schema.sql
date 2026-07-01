-- ============================================
-- MeridianMart Staging Schema
-- Day 5: Typed columns + constraints
-- Promotes clean data from raw layer
-- ============================================

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS audit;

-- ============================================
-- staging.transactions
-- Source: raw.transactions
-- Typed columns + business rule constraints
-- ============================================

CREATE TABLE staging.transactions (
    transaction_id    SERIAL PRIMARY KEY,
    transaction_date  TIMESTAMP NOT NULL,
    store_id          TEXT NOT NULL,
    staff_name        TEXT NOT NULL,
    receipt_no        TEXT NOT NULL,
    customer_phone    TEXT,
    product_sold      TEXT NOT NULL,
    quantity          INTEGER NOT NULL
                      CHECK (quantity BETWEEN 1 AND 5),
    payment_method    TEXT NOT NULL
                      CHECK (payment_method IN ('Cash', 'Card', 'Transfer')),
    source_sheet      TEXT NOT NULL,
    extracted_at      TIMESTAMP DEFAULT NOW(),

    -- Ensure no duplicate receipts + products loaded twice
    UNIQUE (receipt_no, product_sold)
);

-- ============================================
-- staging.products
-- Source: raw.products
-- ============================================

CREATE TABLE staging.products (
    product_id      TEXT PRIMARY KEY,
    product_name    TEXT NOT NULL,
    category        TEXT NOT NULL,
    unit_price_ghs  NUMERIC(10, 2) NOT NULL
                    CHECK (unit_price_ghs > 0),
    last_updated    DATE,
    updated_by      TEXT,
    extracted_at    TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- staging.staff
-- Source: raw.staff
-- Note: store_city dropped (redundant with
-- stores table)
-- ============================================

CREATE TABLE staging.staff (
    staff_id            TEXT PRIMARY KEY,
    full_name           TEXT NOT NULL,
    role                TEXT NOT NULL
                        CHECK (role IN (
                            'Cashier',
                            'Sales Associate',
                            'Stock Clerk',
                            'Security'
                        )),
    store_id            TEXT NOT NULL,
    phone_number        TEXT,
    date_hired          DATE,
    employment_status   TEXT NOT NULL
                        CHECK (employment_status IN (
                            'Active',
                            'Inactive'
                        )),
    extracted_at        TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- staging.managers
-- Source: raw.managers
-- ============================================

CREATE TABLE staging.managers (
    manager_id      TEXT PRIMARY KEY,
    full_name       TEXT NOT NULL,
    role            TEXT NOT NULL
                    CHECK (role IN (
                        'Store Manager',
                        'Assistant Store Manager',
                        'Regional Manager'
                    )),
    store_id        TEXT NOT NULL,
    phone_number    TEXT,
    email           TEXT,
    date_appointed  DATE,
    reports_to      TEXT,
    extracted_at    TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- staging.stores
-- Source: raw.stores
-- ============================================

CREATE TABLE staging.stores (
    store_id      TEXT PRIMARY KEY,
    city          TEXT NOT NULL,
    region        TEXT NOT NULL
                  CHECK (region IN (
                      'Southern Region',
                      'Middle Belt Region',
                      'Northern Region'
                  )),
    extracted_at  TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- audit.validation_log
-- Captures rows that fail staging constraints
-- ============================================

CREATE TABLE audit.validation_log (
    log_id        SERIAL PRIMARY KEY,
    table_name    TEXT NOT NULL,
    check_name    TEXT NOT NULL,
    store_id      TEXT,
    source_sheet  TEXT,
    raw_value     TEXT,
    flagged_at    TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- MeridianMart Staging Schema
-- Day 5: Typed columns + constraints
-- ============================================

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS audit;

-- staging.transactions
CREATE TABLE staging.transactions (
    transaction_id    SERIAL PRIMARY KEY,
    transaction_date  TIMESTAMP NOT NULL,
    store_id          TEXT NOT NULL,
    staff_name        TEXT NOT NULL,
    receipt_no        TEXT NOT NULL,
    customer_phone    TEXT,
    product_sold      TEXT NOT NULL,
    quantity          INTEGER NOT NULL
                      CHECK (quantity BETWEEN 1 AND 5),
    payment_method    TEXT NOT NULL
                      CHECK (payment_method IN ('Cash', 'Card', 'Transfer')),
    source_sheet      TEXT NOT NULL,
    extracted_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE (receipt_no, product_sold)
);

-- staging.products
CREATE TABLE staging.products (
    product_id      TEXT PRIMARY KEY,
    product_name    TEXT NOT NULL,
    category        TEXT NOT NULL,
    unit_price_ghs  NUMERIC(10, 2) NOT NULL
                    CHECK (unit_price_ghs > 0),
    last_updated    DATE,
    updated_by      TEXT,
    extracted_at    TIMESTAMP DEFAULT NOW()
);

-- staging.staff
CREATE TABLE staging.staff (
    staff_id            TEXT PRIMARY KEY,
    full_name           TEXT NOT NULL,
    role                TEXT NOT NULL
                        CHECK (role IN (
                            'Cashier',
                            'Sales Associate',
                            'Stock Clerk',
                            'Security'
                        )),
    store_id            TEXT NOT NULL,
    phone_number        TEXT,
    date_hired          DATE,
    employment_status   TEXT NOT NULL
                        CHECK (employment_status IN (
                            'Active',
                            'Inactive'
                        )),
    extracted_at        TIMESTAMP DEFAULT NOW()
);

-- staging.managers
CREATE TABLE staging.managers (
    manager_id      TEXT PRIMARY KEY,
    full_name       TEXT NOT NULL,
    role            TEXT NOT NULL
                    CHECK (role IN (
                        'Store Manager',
                        'Assistant Store Manager',
                        'Regional Manager'
                    )),
    store_id        TEXT NOT NULL,
    phone_number    TEXT,
    email           TEXT,
    date_appointed  DATE,
    reports_to      TEXT,
    extracted_at    TIMESTAMP DEFAULT NOW()
);

-- staging.stores
CREATE TABLE staging.stores (
    store_id      TEXT PRIMARY KEY,
    city          TEXT NOT NULL,
    region        TEXT NOT NULL
                  CHECK (region IN (
                      'Southern Region',
                      'Middle Belt Region',
                      'Northern Region'
                  )),
    extracted_at  TIMESTAMP DEFAULT NOW()
);

-- audit.validation_log
CREATE TABLE audit.validation_log (
    log_id        SERIAL PRIMARY KEY,
    table_name    TEXT NOT NULL,
    check_name    TEXT NOT NULL,
    store_id      TEXT,
    source_sheet  TEXT,
    raw_value     TEXT,
    flagged_at    TIMESTAMP DEFAULT NOW()
);


