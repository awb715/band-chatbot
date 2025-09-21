import csv
import json
from pathlib import Path
from typing import List, Dict, Any

YEARS = list(range(2012, 2018)) + [2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025]

# Resolve testing/json directory relative to this file
SCRIPT_DIR = Path(__file__).resolve().parent
TESTING_DIR = SCRIPT_DIR.parent
JSON_DIR = TESTING_DIR / "json"


def load_year_file(year: int) -> List[Dict[str, Any]]:
    file_path = JSON_DIR / f"setlists_{year}.json"
    if not file_path.exists():
        print(f"Skipping missing file: {file_path}")
        return []
    with file_path.open("r", encoding="utf-8-sig") as f:
        payload = json.load(f)
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        print(f"Unexpected JSON structure in {file_path} - expected object with 'data' array")
        return []
    return data


def main() -> None:
    JSON_DIR.mkdir(parents=True, exist_ok=True)
    out_path = JSON_DIR / "setlists_external_ids.csv"

    with out_path.open("w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["year", "external_id"])  # external_id corresponds to uniqueid in JSON

        for year in YEARS:
            records = load_year_file(year)
            count = 0
            for rec in records:
                uniqueid = rec.get("uniqueid")
                if uniqueid is None:
                    continue
                writer.writerow([year, uniqueid])
                count += 1
            print(f"Year {year}: wrote {count} IDs")

    print(f"Wrote CSV -> {out_path}")


if __name__ == "__main__":
    main()
