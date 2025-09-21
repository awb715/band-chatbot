import os
import json
from pathlib import Path
from typing import List, Dict, Any, Optional, Set, Tuple

import requests

REST_BASE = "/rest/v1"
REQUEST_TIMEOUT_SECONDS = 120
PAGE_SIZE = 10000

# Directories
SCRIPT_DIR = Path(__file__).resolve().parent
TESTING_DIR = SCRIPT_DIR.parent
JSON_DIR = TESTING_DIR / "json"


def load_env_file(path: Path) -> None:
    if not path.exists() or not path.is_file():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = val


def preload_env_from_common_paths() -> None:
    base = Path.cwd()
    candidates = [
        base / ".env",
        base / ".env.local",
        base / ".env.development",
        base / ".env.template",
        base / "supabase" / ".env",
        base / "supabase" / ".env.local",
        base / "supabase" / ".env.template",
    ]
    for p in candidates:
        load_env_file(p)


def load_year_file(year: int) -> List[Dict[str, Any]]:
    file_path = JSON_DIR / f"setlists_{year}.json"
    if not file_path.exists():
        raise FileNotFoundError(f"Missing file: {file_path}")
    with file_path.open("r", encoding="utf-8-sig") as f:
        payload = json.load(f)
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        raise ValueError(f"Unexpected JSON structure in {file_path} - expected object with 'data' array")
    return data


def fetch_all_rows(
    supabase_url: str,
    token: str,
    schema: str,
    table: str,
    select_cols: str,
) -> List[Dict[str, Any]]:
    url = supabase_url.rstrip("/") + REST_BASE + f"/{table}"
    headers = {
        "Authorization": f"Bearer {token}",
        "apikey": token,
        "Accept-Profile": schema,
        "Prefer": "count=exact",
    }
    params = [("select", select_cols)]
    rows: List[Dict[str, Any]] = []
    range_from = 0
    while True:
        range_to = range_from + PAGE_SIZE - 1
        page_headers = dict(headers)
        page_headers["Range"] = f"items={range_from}-{range_to}"
        resp = requests.get(url, headers=page_headers, params=params, timeout=REQUEST_TIMEOUT_SECONDS)
        resp.raise_for_status()
        data = resp.json()
        rows.extend(data)
        content_range = resp.headers.get("Content-Range") or ""
        if "/" in content_range:
            try:
                total = int(content_range.split("/")[-1])
            except ValueError:
                total = None
        else:
            total = None
        if not data or (total is not None and range_to + 1 >= total):
            break
        range_from += PAGE_SIZE
    return rows


def bronze_ids_by_year(supabase_url: str, token: str, year: int) -> Set[str]:
    rows = fetch_all_rows(supabase_url, token, schema="raw_data", table="setlists", select_cols="external_id,data")
    ids: Set[str] = set()
    for r in rows:
        data = r.get("data") or {}
        sd = data.get("showdate")
        if not sd or len(sd) < 4:
            continue
        try:
            y = int(sd[:4])
        except ValueError:
            continue
        if y == year:
            eid = r.get("external_id")
            if eid is not None:
                ids.add(str(eid))
    return ids


def silver_ids_by_year(supabase_url: str, token: str, year: int) -> Set[str]:
    rows = fetch_all_rows(supabase_url, token, schema="silver", table="setlists", select_cols="external_id,showdate")
    ids: Set[str] = set()
    for r in rows:
        sd = r.get("showdate")
        if not sd or len(sd) < 4:
            continue
        try:
            y = int(str(sd)[:4])
        except ValueError:
            continue
        if y == year:
            eid = r.get("external_id")
            if eid is not None:
                ids.add(str(eid))
    return ids


def reconcile_years(years: List[int]) -> None:
    preload_env_from_common_paths()
    supabase_url = os.environ.get("SUPABASE_URL", "").strip()
    service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    anon_key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    token = service_role_key or anon_key

    if not supabase_url or not token:
        raise RuntimeError("Missing SUPABASE_URL and/or SUPABASE_SERVICE_ROLE_KEY/ANON")

    report: Dict[str, Any] = {}

    for year in years:
        json_records = load_year_file(year)
        json_ids = {str(rec.get("uniqueid")) for rec in json_records if rec.get("uniqueid") is not None}

        bronze_ids = bronze_ids_by_year(supabase_url, token, year)
        silver_ids = silver_ids_by_year(supabase_url, token, year)

        report[str(year)] = {
            "json_count": len(json_ids),
            "bronze_count": len(bronze_ids),
            "silver_count": len(silver_ids),
            "json_minus_bronze": sorted(list(json_ids - bronze_ids))[:50],
            "bronze_minus_json": sorted(list(bronze_ids - json_ids))[:50],
            "bronze_minus_silver": sorted(list(bronze_ids - silver_ids))[:50],
            "silver_minus_bronze": sorted(list(silver_ids - bronze_ids))[:50],
        }
        print(
            f"Reconcile {year}: json={len(json_ids)} bronze={len(bronze_ids)} silver={len(silver_ids)}"
        )

    out_path = JSON_DIR / "reconciliation_report.json"
    out_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"Wrote reconciliation report -> {out_path}")


if __name__ == "__main__":
    years_to_reconcile = [2012, 2013, 2014, 2015, 2016, 2017, 2023, 2024, 2025]
    reconcile_years(years_to_reconcile)
