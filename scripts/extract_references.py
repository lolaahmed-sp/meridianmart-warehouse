# ============================================
# MeridianMart Data Pipeline
# Day 3: Extract Reference Sheets → PostgreSQL
# ============================================

import gspread
import psycopg2
from dotenv import load_dotenv
import os

# Load credentials from .env file
load_dotenv()

# ============================================
# Database connection
# ============================================
def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD")
    )

# ============================================
# Google Sheets connection
# ============================================
def get_gspread_client():
    gc = gspread.service_account(
        filename=os.getenv("GOOGLE_CREDENTIALS_PATH")
    )
    return gc

# ============================================
# Reference sheet configurations
# Sheet URL : target raw table : column list
# ============================================
REFERENCE_CONFIG = [
    {
        "name": "Products",
        "sheet_url": "https://docs.google.com/spreadsheets/d/1oDXxaZLD2KP1U4bfxtY9YiipIaA2FABDL19adSCw2rk/edit?gid=2010423315#gid=2010423315",
        "table": "raw.products",
        "columns": [
            "product_id", "product_name", "category",
            "unit_price_ghs", "last_updated", "updated_by"
        ]
    },
    {
        "name": "Staff",
        "sheet_url": "https://docs.google.com/spreadsheets/d/1iR3ghJkSiEV11ZrVtcvCKbwRhke9HeictvA6f-sVEZ0/edit?gid=756349048#gid=756349048",
        "table": "raw.staff",
        "columns": [
            "staff_id", "full_name", "role", "store_id",
            "store_city", "phone_number", "date_hired",
            "employment_status"
        ]
    },
    {
        "name": "Managers",
        "sheet_url": "https://docs.google.com/spreadsheets/d/1shTuXYx7jrUOi6aXWDHfFwTI_1sQCGuIAngOk_UxpkM/edit?gid=1575394710#gid=1575394710",
        "table": "raw.managers",
        "columns": [
            "manager_id", "full_name", "role", "store_id",
            "phone_number", "email", "date_appointed", "reports_to"
        ]
    },
    {
        "name": "Stores",
        "sheet_url": "https://docs.google.com/spreadsheets/d/1VLadzdv5sba3iFEg8Un2OkE_tlnFeNaHg2YxWvH8Az8/edit?gid=1943471710#gid=1943471710",
        "table": "raw.stores",
        "columns": ["store_id", "city", "region"]
    }
]

# ============================================
# Load one reference sheet into PostgreSQL
# ============================================
def load_reference_sheet(gc, config, conn):
    name    = config["name"]
    url     = config["sheet_url"]
    table   = config["table"]
    columns = config["columns"]

    print(f"\nLoading {name}...")

    # Open the sheet and get all rows as list of dicts
    spreadsheet = gc.open_by_url(url)
    worksheet   = spreadsheet.sheet1
    rows        = worksheet.get_all_records()

    if not rows:
        print(f"  WARNING: No data found in {name} sheet")
        return

    # Build the INSERT statement
    col_names    = ", ".join(columns)
    placeholders = ", ".join(["%s"] * len(columns))
    insert_sql   = f"""
        INSERT INTO {table} ({col_names})
        VALUES ({placeholders})
    """

    cursor = conn.cursor()

    # TRUNCATE first so we don't duplicate on re-runs
    cursor.execute(f"TRUNCATE TABLE {table};")
    print(f"  Truncated {table}")

    # Insert every row
    row_count = 0
    for row in rows:
        values = [str(row.get(col, "")) for col in columns]
        cursor.execute(insert_sql, values)
        row_count += 1

    conn.commit()
    cursor.close()
    print(f"  {table}: {row_count} rows loaded ✅")

# ============================================
# Main runner
# ============================================
def main():
    print("Starting MeridianMart reference data extraction...")

    # Connect to Google Sheets
    gc   = get_gspread_client()

    # Connect to PostgreSQL
    conn = get_db_connection()

    # Load each reference sheet
    for config in REFERENCE_CONFIG:
        load_reference_sheet(gc, config, conn)

    conn.close()
    print("\nAll reference sheets loaded successfully!")

if __name__ == "__main__":
    main()

