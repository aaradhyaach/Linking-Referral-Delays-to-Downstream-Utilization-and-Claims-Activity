import os
import pandas as pd
from sqlalchemy import create_engine, text
from tqdm import tqdm

# --------- CONFIG ----------
SERVER = "referrals-epic-portfolio.database.windows.net"
DATABASE = "ReferralLeakageDB"
USERNAME = "YOURUSER"   # often works best as user@YOURSERVERNAME (without .database.windows.net)
PASSWORD = "YOURPASSWORD"
CSV_DIR = "../data/csv"  # folder containing the synthea csvs
SCHEMA = "raw"
# ----------------------------------------

def make_engine():
    # ODBC Driver 18 requires encryption; TrustServerCertificate can be set to yes for dev
    conn_str = (
        "mssql+pyodbc://{user}:{pwd}@{server}:1433/{db}"
        "?driver=ODBC+Driver+18+for+SQL+Server"
        "&Encrypt=yes"
        "&TrustServerCertificate=yes"
    ).format(user=USERNAME, pwd=PASSWORD, server=SERVER, db=DATABASE)

    return create_engine(conn_str, fast_executemany=True)

def truncate_table(engine, schema, table):
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE TABLE {schema}.{table};"))

def load_one_csv(engine, csv_path, schema, table):
    df = pd.read_csv(csv_path)

    # Normalize column names to match SQL (Synthea uses exact names; keep as-is)
    # df.columns = [c.strip() for c in df.columns]

    # Convert empty strings to NaN so NULLs insert cleanly
    df = df.replace({"": None})

    # Insert
    df.to_sql(table, con=engine, schema=schema, if_exists="append", index=False, chunksize=2000, method=None)

def main():
    engine = make_engine()

    # Map CSV filenames -> table names
    # (Adjust if your zip has different names)
    mapping = {
        "patients.csv": "patients",
        "organizations.csv": "organizations",
        "providers.csv": "providers",
        "payers.csv": "payers",
        "payer_transitions.csv": "payer_transitions",
        "encounters.csv": "encounters",
        "conditions.csv": "conditions",
        "procedures.csv": "procedures",
        "observations.csv": "observations",
        "medications.csv": "medications",
        "immunizations.csv": "immunizations",
        "allergies.csv": "allergies",
        "careplans.csv": "careplans",
        "devices.csv": "devices",
        "supplies.csv": "supplies",
        "imaging_studies.csv": "imaging_studies",
        "claims.csv": "claims",
        "claims_transactions.csv": "claims_transactions",
    }

    # Only load files that exist in your folder
    files = [(f, t) for f, t in mapping.items() if os.path.exists(os.path.join(CSV_DIR, f))]

    if not files:
        raise RuntimeError(f"No mapped CSVs found in {CSV_DIR}. Check your unzip path.")

    print(f"Found {len(files)} CSVs to load from {CSV_DIR}")

    for csv_file, table in tqdm(files, desc="Loading CSVs"):
        path = os.path.join(CSV_DIR, csv_file)

        # Optional: clear table before load
        # truncate_table(engine, SCHEMA, table)

        load_one_csv(engine, path, SCHEMA, table)

    print("✅ Done loading all CSVs.")

if __name__ == "__main__":
    main()
