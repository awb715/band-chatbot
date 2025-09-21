import os
import json
import time
from pathlib import Path
from typing import List, Dict, Any, Optional, Set, Tuple

import requests


EDGE_PATH = "/functions/v1/ingest_raw_data"
DEFAULT_BATCH_SIZE = 250  # smaller batches to avoid timeouts
REQUEST_TIMEOUT_SECONDS = 300  # give Edge function more time per request
RETRY_SLEEP_SECONDS = 2
MAX_RETRIES = 2
MIN_BATCH_SIZE = 50
REST_BASE = "/rest/v1"

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
        # strip optional surrounding quotes
        val = val.strip().strip('"').strip("'")
        # do not override if already set in the environment
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


def load_year_file(year: int, base_dir: Path) -> List[Dict[str, Any]]:
    file_path = base_dir / f"setlists_{year}.json"
    if not file_path.exists():
        raise FileNotFoundError(f"Missing file: {file_path}")
    # Use utf-8-sig to handle potential BOM
    with file_path.open("r", encoding="utf-8-sig") as f:
        payload = json.load(f)
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        raise ValueError(f"Unexpected JSON structure in {file_path} - expected object with 'data' array")
    return data


def chunk_list(items: List[Any], chunk_size: int) -> List[List[Any]]:
    chunks: List[List[Any]] = []
    start_index = 0
    total = len(items)
    while start_index < total:
        end_index = min(start_index + chunk_size, total)
        chunks.append(items[start_index:end_index])
        start_index = end_index
    return chunks


def post_batch(supabase_url: str, token: str, batch: List[Dict[str, Any]]) -> Dict[str, Any]:
    url = supabase_url.rstrip("/") + EDGE_PATH
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "apikey": token,
    }
    body = {
        "mode": "manual",
        "yearData": batch,
    }
    last_error: Optional[Exception] = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.post(url, headers=headers, json=body, timeout=REQUEST_TIMEOUT_SECONDS)
            if resp.status_code == 401:
                raise RuntimeError("Unauthorized (401). Check your SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY.")
            if resp.status_code >= 500:
                raise RuntimeError(f"Server error {resp.status_code}: {resp.text}")
            resp.raise_for_status()
            return resp.json()
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_SLEEP_SECONDS)
            else:
                raise
    # Should not reach here
    raise RuntimeError(f"Failed after retries: {last_error}")


def post_batch_adaptive(supabase_url: str, token: str, batch: List[Dict[str, Any]]) -> Dict[str, Any]:
    try:
        return post_batch(supabase_url, token, batch)
    except Exception as exc:  # noqa: BLE001
        if len(batch) <= MIN_BATCH_SIZE:
            raise
        mid = len(batch) // 2
        left = batch[:mid]
        right = batch[mid:]
        print(f"    Timeout/error encountered ({exc}). Splitting batch {len(batch)} -> {len(left)} + {len(right)}")
        res_left = post_batch_adaptive(supabase_url, token, left)
        res_right = post_batch_adaptive(supabase_url, token, right)
        # Aggregate totals
        agg = {
            "success": bool(res_left.get("success", False)) and bool(res_right.get("success", False)),
            "total_new_records": int(res_left.get("total_new_records", 0)) + int(res_right.get("total_new_records", 0)),
            "total_updated_records": int(res_left.get("total_updated_records", 0)) + int(res_right.get("total_updated_records", 0)),
            "results": (res_left.get("results") or []) + (res_right.get("results") or []),
        }
        return agg


def get_distinct_external_ids(supabase_url: str, token: str, schema_table: str, date_column_expr: str, year: int) -> Set[str]:
    """Fetch distinct external_id values for a given year from a table.
    schema_table: e.g., "raw_data.setlists" or "silver.setlists"
    date_column_expr: e.g., "data->>showdate" for bronze, "showdate" for silver
    """
    url = supabase_url.rstrip("/") + REST_BASE + f"/{schema_table}"
    headers = {
        "Authorization": f"Bearer {token}",
        "apikey": token,
        "Prefer": "count=exact",
    }
    start = f"{year}-01-01"
    end = f"{year+1}-01-01"
    params = {
        "select": "external_id",
        "distinct": "true",
        f"{date_column_expr}=gte": start,
        f"{date_column_expr}=lt": end,
    }
    # pagination loop to gather all distinct ids if server limits rows
    ids: Set[str] = set()
    range_from = 0
    page_size = 10000
    while True:
        range_to = range_from + page_size - 1
        page_headers = dict(headers)
        page_headers["Range"] = f"items={range_from}-{range_to}"
        resp = requests.get(url, headers=page_headers, params=params, timeout=REQUEST_TIMEOUT_SECONDS)
        resp.raise_for_status()
        data = resp.json()
        for row in data:
            eid = row.get("external_id")
            if eid is not None:
                ids.add(str(eid))
        content_range = resp.headers.get("Content-Range") or ""
        # Content-Range: items 0-999/12345
        if "/" in content_range:
            _, total_str = content_range.split("/", 1)
            try:
                total = int(total_str)
            except ValueError:
                total = None
        else:
            total = None
        # stop when we've retrieved all or when no data returned
        if not data or (total is not None and range_to + 1 >= total):
            break
        range_from += page_size
    return ids


def reconcile_years(years: List[int]) -> None:
    supabase_url = os.environ.get("SUPABASE_URL", "").strip()
    service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    anon_key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    token = service_role_key or anon_key
    base_dir = Path.cwd()

    report: Dict[str, Any] = {}

    for year in years:
        # JSON file
        json_records = load_year_file(year, base_dir)
        json_ids = {str(rec.get("uniqueid")) for rec in json_records if rec.get("uniqueid") is not None}

        # Bronze (raw_data)
        bronze_ids = get_distinct_external_ids(
            supabase_url, token,
            schema_table="raw_data.setlists",
            date_column_expr="data->>showdate",
            year=year,
        )

        # Silver
        silver_ids = get_distinct_external_ids(
            supabase_url, token,
            schema_table="silver.setlists",
            date_column_expr="showdate",
            year=year,
        )

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

    # Save report for inspection
    out_path = Path("reconciliation_report.json")
    out_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"Wrote reconciliation report -> {out_path}")


def ingest_years(years: List[int], batch_size: int = DEFAULT_BATCH_SIZE) -> None:
    # load env from common files first (does not overwrite existing env vars)
    preload_env_from_common_paths()

    supabase_url = os.environ.get("SUPABASE_URL", "").strip()
    service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    anon_key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    token = service_role_key or anon_key

    if not supabase_url or not token:
        raise RuntimeError(
            "Missing SUPABASE_URL and/or SUPABASE_SERVICE_ROLE_KEY/ANON env vars. "
            "Set them in your shell or a .env(.template) file at project root."
        )

    for year in years:
        records = load_year_file(year, JSON_DIR)
        print(f"Year {year}: {len(records)} records found")

        batches = chunk_list(records, batch_size)
        total_new = 0
        total_updated = 0

        for idx, batch in enumerate(batches, start=1):
            print(f"  Posting batch {idx}/{len(batches)} (size={len(batch)})...")
            result = post_batch_adaptive(supabase_url, token, batch)
            new_count = int(result.get("total_new_records", 0))
            updated_count = int(result.get("total_updated_records", 0))
            total_new += new_count
            total_updated += updated_count
            print(f"  -> success={result.get('success', False)} new={new_count} updated={updated_count}")

        print(f"Finished {year}: total_new={total_new} total_updated={total_updated}")


if __name__ == "__main__":
    years_to_process = [2012, 2013, 2014, 2015, 2016, 2017, 2023, 2024, 2025]
    ingest_years(years_to_process, batch_size=DEFAULT_BATCH_SIZE)
    # 3-way reconciliation
    reconcile_years(years_to_process)
