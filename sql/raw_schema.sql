-- ============================================
-- MeridianMart Raw Schema
-- Day 2: All columns TEXT, no constraints
-- ============================================

CREATE SCHEMA IF NOT EXISTS raw;

-- ============================================
-- Transactions table (unified - all 11 stores)
-- ============================================
CREATE TABLE raw.transactions (
    timestamp        TEXT,
    store_id          TEXT,
    staff_name        TEXT,
    receipt_no        TEXT,
    customer_phone    TEXT,
    product_sold      TEXT,
    quantity          TEXT,
    payment_method    TEXT,
    source_sheet      TEXT,
    extracted_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- Products reference table
-- Source: Products_Master Google Sheet
-- 65 products across 15 categories
-- ============================================

CREATE TABLE raw.products (
    product_id        TEXT,
    product_name      TEXT,
    category          TEXT,
    unit_price_ghs    TEXT,
    last_updated      TEXT,
    updated_by        TEXT,
    extracted_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- Staff reference table
-- Source: Staff_Master Google Sheet
-- 90 employees across 11 stores
-- ============================================

CREATE TABLE raw.staff (
    staff_id            TEXT,
    full_name           TEXT,
    role                TEXT,
    store_id            TEXT,
    store_city          TEXT,
    phone_number        TEXT,
    date_hired          TEXT,
    employment_status   TEXT,
    extracted_at        TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- Managers reference table
-- Source: Managers_Master Google Sheet
-- 25 managers (11 store, 11 assistant, 3 regional)
-- ============================================

CREATE TABLE raw.managers (
    manager_id        TEXT,
    full_name         TEXT,
    role              TEXT,
    store_id          TEXT,
    phone_number      TEXT,
    email             TEXT,
    date_appointed    TEXT,
    reports_to        TEXT,
    extracted_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- Stores reference table
-- Source: Stores_Master Google Sheet
-- 11 stores across 3 regions in Ghana
-- ============================================

CREATE TABLE raw.stores (
    store_id          TEXT,
    city              TEXT,
    region            TEXT,
    extracted_at      TIMESTAMP DEFAULT NOW()
);

