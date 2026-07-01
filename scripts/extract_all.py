# ============================================
# MeridianMart Data Pipeline
# Day 4: Extract All 11 Store Sheets → raw.transactions
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
# Header normalisation map
# Maps every variation found across all 11
# store sheets to one canonical column name
# ============================================
HEADER_MAP = {
    "Timestamp":                         "timestamp",
    "Store ID":                          "store_id",
    "Staff Name":                        "staff_name",
    "Receipt No.":                       "receipt_no",
    "Customer Phone Number (Optional)":  "customer_phone",
    "Product Sold":                      "product_sold",
    "Quantity":                          "quantity",
    "Payment Method":                    "payment_method",
}

def normalise_headers(raw_headers):
    """
    Takes the raw header row from a sheet and maps
    each header to its canonical name using HEADER_MAP.
    Returns a list of normalised column names.
    """
    normalised = []
    for header in raw_headers:
        canonical = HEADER_MAP.get(header.strip())
        if canonical:
            normalised.append(canonical)
        else:
            normalised.append(header.strip().lower().replace(" ", "_"))
    return normalised

# ============================================
# Store configuration
# Maps store_id to its Google Sheet URL
# Replace each URL with your actual sheet URL
# ============================================
STORE_CONFIG = [
    {
        "store_id":    "S001",
        "sheet_name":  "SalesLog_S001",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1dob3p4TRkWj-jN3imsNcihFSajZ_9u4ZkEKWdBVrDV8/edit?gid=436133425#gid=436133425"
    },
    {
        "store_id":    "S002",
        "sheet_name":  "SalesLog_S002",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1hEb2KZZlqD_cyRfSF8KDiPCAcQ8Igqr89ooJ2yfqstg/edit?gid=306551302#gid=306551302"
    },
    {
        "store_id":    "S003",
        "sheet_name":  "SalesLog_S003",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1NkNRsHkMO8jg5BCG0igHYdorFqKx-APmoRR5K15muDo/edit?gid=1655524359#gid=1655524359"
    },
    {
        "store_id":    "S004",
        "sheet_name":  "SalesLog_S004",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1iAgxk_XP8rZBXxHa6zH7YZQno3vVqaEVD8vpHuqB-2U/edit?gid=451484431#gid=451484431"
    },
    {
        "store_id":    "S005",
        "sheet_name":  "SalesLog_S005",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1R04N8FmX3KeMdKb9-cSZDgluBq2N4Q8_WNAsXOXbGlc/edit?gid=785270028#gid=785270028"
    },
    {
        "store_id":    "S006",
        "sheet_name":  "SalesLog_S006",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1q5_-lY_trscnJOwiFWedyOOPC2agq0vnqnXVTc9IgG0/edit?gid=430524491#gid=430524491"
    },
    {
        "store_id":    "S007",
        "sheet_name":  "SalesLog_S007",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1imTaeiPNKWO2jLg5YBjny6UlcXnlFqkHcNKvj0cDBJ4/edit?gid=1108366875#gid=1108366875"
    },
    {
        "store_id":    "S008",
        "sheet_name":  "SalesLog_S008",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1OXcsRtjx7GSbtVmvDZr-KogCVXsEhe_AkUoF9wOyngw/edit?gid=487171073#gid=487171073"
    },
    {
        "store_id":    "S009",
        "sheet_name":  "SalesLog_S009",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1sXTnfqBRcg1u_-DRyn_-yWZdIGG96E_mQoHsiHJz6FA/edit?gid=34752732#gid=34752732"
    },
    {
        "store_id":    "S010",
        "sheet_name":  "SalesLog_S010",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/1CHfGZ6-D_meZj3t5y3KIWu3qvD9vNTWdS24udz23zmE/edit?gid=639136651#gid=639136651"
    },
    {
        "store_id":    "S011",
        "sheet_name":  "SalesLog_S011",
        "sheet_url":   "https://docs.google.com/spreadsheets/d/10u8ny3KHNSQ1SCSCwEjdmFiULhPcrn5wSnK-RVB6REM/edit?gid=1291577185#gid=1291577185"
    },
]

# ============================================
# Extract one store sheet and load into
# raw.transactions
# ============================================
def load_store_sheet(gc, store, conn):
    store_id   = store["store_id"]
    sheet_name = store["sheet_name"]
    sheet_url  = store["sheet_url"]

    print(f"\nLoading {sheet_name} ({store_id})...")

    # Open the sheet
    spreadsheet = gc.open_by_url(sheet_url)
    worksheet   = spreadsheet.sheet1

    # Get all values including header row
    all_values  = worksheet.get_all_values()

    if len(all_values) < 2:
        print(f"  WARNING: No data rows found in {sheet_name}")
        return 0

    # First row is headers — normalise them
    raw_headers  = all_values[0]
    headers      = normalise_headers(raw_headers)
    data_rows    = all_values[1:]

    # INSERT statement for raw.transactions
    insert_sql = """
        INSERT INTO raw.transactions (
            timestamp,
            store_id,
            staff_name,
            receipt_no,
            customer_phone,
            product_sold,
            quantity,
            payment_method,
            source_sheet
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """

    cursor    = conn.cursor()
    row_count = 0

    for row in data_rows:
        # Map each row value to its canonical column name
        row_dict = dict(zip(headers, row))

        values = (
            row_dict.get("timestamp",       ""),
            store_id,                            # injected metadata
            row_dict.get("staff_name",      ""),
            row_dict.get("receipt_no",      ""),
            row_dict.get("customer_phone",  ""),
            row_dict.get("product_sold",    ""),
            row_dict.get("quantity",        ""),
            row_dict.get("payment_method",  ""),
            sheet_name,                          # injected metadata
        )

        cursor.execute(insert_sql, values)
        row_count += 1

    conn.commit()
    cursor.close()

    print(f"  {sheet_name}: {row_count} rows loaded ✅")
    return row_count

# ============================================
# Main runner
# ============================================
def main():
    print("Starting MeridianMart transaction data extraction...")
    print(f"Processing {len(STORE_CONFIG)} stores...\n")

    # Connect to Google Sheets and PostgreSQL
    gc   = get_gspread_client()
    conn = get_db_connection()

    # Truncate transactions table before loading
    # so we don't duplicate on re-runs
    cursor = conn.cursor()
    cursor.execute("TRUNCATE TABLE raw.transactions;")
    conn.commit()
    cursor.close()
    print("Truncated raw.transactions")

    # Loop through all 11 stores
    total_rows = 0
    for store in STORE_CONFIG:
        rows       = load_store_sheet(gc, store, conn)
        total_rows += rows

    conn.close()

    print(f"\n{'='*45}")
    print(f"Extraction complete!")
    print(f"Total rows loaded: {total_rows}")
    print(f"{'='*45}")

if __name__ == "__main__":
    main()


