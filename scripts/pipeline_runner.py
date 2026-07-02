# ============================================
# MeridianMart Data Pipeline
# Week 2 Day 4: Pipeline Runner
# Executes all steps in dependency order:
# 1. Extract reference sheets
# 2. Extract all 11 store sheets
# 3. Load staging from raw
# 4. Run SQL validation checks
# 5. Build dimension tables
# 6. Build fact table
# 7. Build dim_customers
# ============================================

import subprocess
import psycopg2
import os
import sys
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

# ============================================
# Configuration
# ============================================
DB_CONFIG = {
    "host":     os.getenv("DB_HOST"),
    "port":     os.getenv("DB_PORT"),
    "dbname":   os.getenv("DB_NAME"),
    "user":     os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD")
}

# Path to your project folder
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SQL_DIR     = os.path.join(PROJECT_DIR, "sql")
SCRIPTS_DIR = os.path.join(PROJECT_DIR, "scripts")
LOG_FILE    = os.path.join(PROJECT_DIR, "pipeline_run_log.txt")

# ============================================
# Logging helper
# Writes to both terminal and log file
# ============================================
def log(message, level="INFO"):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line      = f"[{timestamp}] [{level}] {message}"
    print(line)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")

# ============================================
# Run a Python script as a subprocess
# ============================================
def run_python_script(script_name):
    script_path = os.path.join(SCRIPTS_DIR, script_name)
    log(f"Running {script_name}...")

    result = subprocess.run(
        [sys.executable, script_path],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        log(f"FAILED: {script_name}", level="ERROR")
        log(result.stderr, level="ERROR")
        raise Exception(f"{script_name} failed — see log for details")

    log(f"Completed {script_name}")
    if result.stdout:
        for line in result.stdout.strip().split("\n"):
            log(f"  {line}")

# ============================================
# Run a SQL file against PostgreSQL
# ============================================
def run_sql_file(sql_filename):
    sql_path = os.path.join(SQL_DIR, sql_filename)
    log(f"Running {sql_filename}...")

    conn   = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()

    with open(sql_path, "r") as f:
        sql = f.read()

    try:
        cursor.execute(sql)
        conn.commit()
        log(f"Completed {sql_filename}")
    except Exception as e:
        conn.rollback()
        log(f"FAILED: {sql_filename} — {str(e)}", level="ERROR")
        raise
    finally:
        cursor.close()
        conn.close()

# ============================================
# Get row count from any table
# ============================================
def get_row_count(table_name):
    conn   = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    cursor.execute(f"SELECT COUNT(*) FROM {table_name};")
    count  = cursor.fetchone()[0]
    cursor.close()
    conn.close()
    return count

# ============================================
# Main pipeline — runs all steps in order
# ============================================
def main():
    # Write separator to log for each run
    with open(LOG_FILE, "a") as f:
        f.write("\n" + "=" * 55 + "\n")
        f.write(f"PIPELINE RUN STARTED: "
                f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 55 + "\n")

    log("MeridianMart Pipeline Runner starting...")
    log(f"Project directory: {PROJECT_DIR}")

    try:
        # ----------------------------------------
        # STEP 1: Extract reference sheets
        # ----------------------------------------
        log("=" * 45)
        log("STEP 1: Extracting reference sheets")
        log("=" * 45)
        run_python_script("extract_references.py")

        ref_counts = {
            "raw.products":  get_row_count("raw.products"),
            "raw.staff":     get_row_count("raw.staff"),
            "raw.managers":  get_row_count("raw.managers"),
            "raw.stores":    get_row_count("raw.stores"),
        }
        for table, count in ref_counts.items():
            log(f"  {table}: {count} rows")

        # ----------------------------------------
        # STEP 2: Extract all 11 store sheets
        # ----------------------------------------
        log("=" * 45)
        log("STEP 2: Extracting all 11 store sheets")
        log("=" * 45)
        run_python_script("extract_all.py")

        txn_count = get_row_count("raw.transactions")
        log(f"  raw.transactions: {txn_count} rows")

        # ----------------------------------------
        # STEP 3: Load staging from raw
        # ----------------------------------------
        log("=" * 45)
        log("STEP 3: Loading staging tables from raw")
        log("=" * 45)
        run_sql_file("load_staging.sql")

        staging_counts = {
            "staging.stores":   get_row_count("staging.stores"),
            "staging.staff":    get_row_count("staging.staff"),
            "staging.managers": get_row_count("staging.managers"),
            "staging.products": get_row_count("staging.products"),
        }
        for table, count in staging_counts.items():
            log(f"  {table}: {count} rows")

        # ----------------------------------------
        # STEP 4: Run SQL validation checks
        # ----------------------------------------
        log("=" * 45)
        log("STEP 4: Running validation checks")
        log("=" * 45)
        run_sql_file("validate.sql")

        audit_count = get_row_count("audit.validation_log")
        log(f"  audit.validation_log: {audit_count} findings")

        if audit_count > 0:
            log("WARNING: Data quality issues found — "
                "check audit.validation_log", level="WARN")
        else:
            log("  All validation checks passed — 0 findings ✅")

        # ----------------------------------------
        # STEP 5: Build dimension tables
        # ----------------------------------------
        log("=" * 45)
        log("STEP 5: Building dimension tables")
        log("=" * 45)
        run_sql_file("build_dimensions.sql")

        dim_counts = {
            "marts.dim_stores":   get_row_count("marts.dim_stores"),
            "marts.dim_staff":    get_row_count("marts.dim_staff"),
            "marts.dim_managers": get_row_count("marts.dim_managers"),
            "marts.dim_products": get_row_count("marts.dim_products"),
            "marts.dim_date":     get_row_count("marts.dim_date"),
        }
        for table, count in dim_counts.items():
            log(f"  {table}: {count} rows")

        # ----------------------------------------
        # STEP 6: Build fact table
        # ----------------------------------------
        log("=" * 45)
        log("STEP 6: Building fact table")
        log("=" * 45)
        run_sql_file("build_fact.sql")

        fact_count = get_row_count("marts.fact_transactions")
        log(f"  marts.fact_transactions: {fact_count} rows")

        # ----------------------------------------
        # STEP 7: Build dim_customers
        # ----------------------------------------
        log("=" * 45)
        log("STEP 7: Building dim_customers")
        log("=" * 45)
        run_sql_file("dim_customers.sql")

        customer_count = get_row_count("marts.dim_customers")
        log(f"  marts.dim_customers: {customer_count} rows")

        # ----------------------------------------
        # STEP 8: Run FK integrity checks
        # ----------------------------------------
        log("=" * 45)
        log("STEP 8: Running FK integrity checks")
        log("=" * 45)

        conn   = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()

        fk_checks = [
            ("no_matching_store",
             """SELECT COUNT(*) FROM marts.fact_transactions ft
                LEFT JOIN marts.dim_stores ds
                ON ft.store_key = ds.store_key
                WHERE ds.store_key IS NULL"""),
            ("no_matching_staff",
             """SELECT COUNT(*) FROM marts.fact_transactions ft
                LEFT JOIN marts.dim_staff dst
                ON ft.staff_key = dst.staff_key
                WHERE dst.staff_key IS NULL"""),
            ("no_matching_product",
             """SELECT COUNT(*) FROM marts.fact_transactions ft
                LEFT JOIN marts.dim_products dp
                ON ft.product_key = dp.product_key
                WHERE dp.product_key IS NULL"""),
            ("no_matching_date",
             """SELECT COUNT(*) FROM marts.fact_transactions ft
                LEFT JOIN marts.dim_date dd
                ON ft.date_key = dd.date_key
                WHERE dd.date_key IS NULL"""),
        ]

        all_clean = True
        for check_name, query in fk_checks:
            cursor.execute(query)
            orphan_count = cursor.fetchone()[0]
            status       = "✅" if orphan_count == 0 else "❌ FAIL"
            log(f"  {check_name}: {orphan_count} orphans {status}")
            if orphan_count > 0:
                all_clean = False

        cursor.close()
        conn.close()

        if all_clean:
            log("All FK integrity checks passed ✅")
        else:
            log("FK integrity issues found — review joins",
                level="WARN")

        # ----------------------------------------
        # Pipeline complete summary
        # ----------------------------------------
        log("=" * 45)
        log("PIPELINE COMPLETE ✅")
        log("=" * 45)
        log(f"  raw.transactions:        {txn_count:>7,} rows")
        log(f"  staging tables loaded:   {sum(staging_counts.values()):>7,} rows")
        log(f"  audit findings:          {audit_count:>7,}")
        log(f"  fact_transactions:       {fact_count:>7,} rows")
        log(f"  dim_customers:           {customer_count:>7,} rows")
        log("=" * 45)

    except Exception as e:
        log(f"PIPELINE FAILED: {str(e)}", level="ERROR")
        sys.exit(1)

if __name__ == "__main__":
    main()

    