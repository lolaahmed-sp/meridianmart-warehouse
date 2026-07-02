# MeridianMart Data Pipeline — Reference Guide

## 1. Project Overview

MeridianMart is a mid-sized retail business with 11 stores across Ghana.
This pipeline centralises 15 Google Sheets data sources into a single
PostgreSQL data warehouse enabling cross-branch reporting and analytics.

**Pipeline type:** ELT (Extract → Load → Transform)
**Schedule:** Daily at 6:00am via cron
**Total records processed:** 56,139 transaction rows across 11 stores

---

## 2. Schema Progression
[Google Drive — 15 Sheets]
↓
Python (gspread + psycopg2)
↓
[PostgreSQL — RAW SCHEMA]
All columns TEXT, no constraints
Tables: raw.transactions, raw.products,
raw.staff, raw.managers, raw.stores
↓
SQL (load_staging.sql)
↓
[PostgreSQL — STAGING SCHEMA]
Typed columns, NOT NULL, CHECK constraints
Tables: staging.transactions, staging.products,
staging.staff, staging.managers, staging.stores
audit.validation_log captures flagged rows
↓
SQL (build_dimensions + build_fact)
↓
[PostgreSQL — MARTS SCHEMA]
Star schema — fact + dimension tables
fact_transactions (56,139 rows)
dim_stores | dim_staff | dim_managers
dim_products | dim_date | dim_customers

---

## 3. Data Sources

| Source | Type | Rows | Loaded by |
|--------|------|------|-----------|
| SalesLog_S001 to S011 (×11) | Google Sheets | 56,139 total | extract_all.py |
| Products_Master | Google Sheets | 65 | extract_references.py |
| Staff_Master | Google Sheets | 90 | extract_references.py |
| Managers_Master | Google Sheets | 25 | extract_references.py |
| Stores_Master | Google Sheets | 11 | extract_references.py |

---

## 4. Transformation Logic Per Table

### raw → staging.transactions
| Column | Raw type | Staging type | Logic |
|--------|----------|--------------|-------|
| timestamp | TEXT | TIMESTAMP | Cast directly |
| quantity | TEXT | INTEGER | Cast — CHECK BETWEEN 1 AND 5 |
| payment_method | TEXT | TEXT | CHECK IN ('Cash','Card','Transfer') |
| customer_phone | TEXT | TEXT | NULLIF blank — walk-ins allowed NULL |
| store_id | TEXT | TEXT | NOT NULL enforced |

### raw → staging.staff
| Column | Raw type | Staging type | Logic |
|--------|----------|--------------|-------|
| date_hired | TEXT | DATE | Excel serial → DATE conversion |
| store_city | TEXT | — | Dropped — redundant with stores table |
| role | TEXT | TEXT | CHECK IN 4 known values |
| employment_status | TEXT | TEXT | CHECK IN ('Active','Inactive') |

### raw → staging.managers
| Column | Raw type | Staging type | Logic |
|--------|----------|--------------|-------|
| date_appointed | TEXT | DATE | Excel serial → DATE conversion |
| role | TEXT | TEXT | CHECK IN 3 known values |
| reports_to | TEXT | TEXT | NULL allowed — regional managers |

### staging → marts.fact_transactions
| Column | Source | Logic |
|--------|--------|-------|
| unit_price_ghs | dim_products | Pulled from product master — not raw form |
| total_amount_ghs | computed | quantity × unit_price_ghs |
| store_key | dim_stores | FK join on store_id |
| staff_key | dim_staff | FK join on full_name + store_id |
| product_key | dim_products | FK join on product_name (LOWER + TRIM) |
| date_key | dim_date | FK join on transaction_date::DATE |

### fact → dim_customers
| Column | Logic |
|--------|-------|
| customer_phone | DISTINCT from fact_transactions |
| first_seen_date | MIN(transaction_date::DATE) |
| total_visits | COUNT(DISTINCT receipt_no) |

---

## 5. Constraint List with Rationale

| Table | Constraint | Rationale |
|-------|-----------|-----------|
| staging.transactions | CHECK quantity BETWEEN 1 AND 5 | Max observed quantity in source data |
| staging.transactions | CHECK payment_method IN (...) | Only 3 valid payment types in business |
| staging.transactions | NOT NULL on 7 columns | Core business fields must always be present |
| staging.transactions | UNIQUE (receipt_no, product_sold) | Prevents duplicate line items on reload |
| staging.staff | CHECK role IN (...) | Only 4 known staff roles |
| staging.staff | CHECK employment_status IN (...) | Binary status — Active or Inactive only |
| staging.managers | CHECK role IN (...) | Only 3 known manager roles |
| staging.stores | CHECK region IN (...) | Only 3 regions in Ghana coverage area |
| staging.products | CHECK unit_price_ghs > 0 | Price must always be positive |
| marts.fact_transactions | FK to all 4 dim tables | Star schema referential integrity |

---

## 6. Validation Checks & audit.validation_log

Three SQL checks run after every extraction:

| Check name | What it detects | Expected result |
|-----------|----------------|-----------------|
| duplicate_receipt_no | Same receipt appearing more than 3 times | 0 findings |
| unmatched_product_name | Products in transactions not in Products Master | 0 findings |
| unmatched_staff_name | Staff names in transactions not in Staff Master | 0 findings |

### Reading audit.validation_log

```sql
-- See all findings by type
SELECT check_name, COUNT(*) AS findings
FROM audit.validation_log
GROUP BY check_name
ORDER BY findings DESC;

-- See detail for a specific check
SELECT store_id, source_sheet, raw_value
FROM audit.validation_log
WHERE check_name = 'unmatched_product_name';
```

### Common error codes and remediation

| check_name | Likely cause | Fix |
|-----------|-------------|-----|
| duplicate_receipt_no | Pipeline ran twice without TRUNCATE | Re-run extract_all.py — TRUNCATE handles it |
| unmatched_product_name | New product added to form not yet in Products Master | Update Products_Master sheet |
| unmatched_staff_name | New cashier added to store not yet in Staff Master | Update Staff_Master sheet |

---

## 7. Pipeline Execution Order

pipeline_runner.py
│
├── Step 1: extract_references.py
│   └── Loads raw.products, raw.staff, raw.managers, raw.stores
│
├── Step 2: extract_all.py
│   └── Loads raw.transactions (all 11 stores)
│
├── Step 3: load_staging.sql
│   └── Promotes raw → staging with type casting
│
├── Step 4: validate.sql
│   └── Runs 3 checks → logs to audit.validation_log
│
├── Step 5: build_dimensions.sql
│   └── Builds 5 dim tables in marts schema
│
├── Step 6: build_fact.sql
│   └── Builds fact_transactions (56,139 rows)
│
├── Step 7: dim_customers.sql
│   └── Derives dim_customers from fact table
│
└── Step 8: FK integrity checks
└── Confirms 0 orphans across all dim joins

---

## 8. Cron Schedule

```bash
# Runs daily at 6:00am
0 6 * * * /path/to/.venv/bin/python3 /path/to/pipeline_runner.py >> pipeline_run_log.txt 2>&1
```

Check the cron entry:
```bash
crontab -l
```

Check the latest pipeline log:
```bash
tail -50 pipeline_run_log.txt
```

---

## 9. Repository Structure
meridianmart-warehouse/
├── docs/
│   ├── MeridianMartArchitectureDiagram.png
│   ├── meridianmart_erd.png
│   ├── pipeline_reference.md
│   └── fk_audit_result.txt
├── scripts/
│   ├── extract_references.py
│   ├── extract_all.py
│   └── pipeline_runner.py
├── sql/
│   ├── raw_schema.sql
│   ├── load_staging.sql
│   ├── staging_schema.sql
│   ├── validate.sql
│   ├── build_dimensions.sql
│   ├── build_fact.sql
│   ├── dim_customers.sql
│   ├── fk_integrity_check.sql
│   └── transformations/
├── .env
├── .gitignore
├── pipeline_run_log.txt
├── README.md
└── requirements.txt

---

## 10. Setup Instructions

```bash
# 1. Clone the repo
git clone https://github.com/lolaahmed-sp/meridianmart-warehouse.git
cd meridianmart-warehouse

# 2. Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Create .env file with credentials
cp .env.example .env
# Edit .env with your PostgreSQL password and Google credentials path

# 5. Create database
psql -U postgres -c "CREATE DATABASE meridianmart;"

# 6. Run raw schema
psql -U postgres -d meridianmart -f sql/raw_schema.sql

# 7. Run staging schema
psql -U postgres -d meridianmart -f sql/staging_schema.sql

# 8. Run full pipeline
python3 scripts/pipeline_runner.py
```

