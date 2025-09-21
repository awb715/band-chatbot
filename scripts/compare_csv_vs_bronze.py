import os
import csv
from pathlib import Path
from typing import Set, List, Dict, Any
import requests

REST_BASE = "/rest/v1"
REQUEST_TIMEOUT_SECONDS = 120
PAGE_SIZE = 10000


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
    for p in [base/".env", base/".env.local", base/".env.development", base/".env.template", base/"supabase"/".env", base/"supabase"/".env.local", base/"supabase"/".env.template"]:
        load_env_file(p)


def fetch_bronze_external_ids(supabase_url: str, token: str) -> Set[str]:
    url = supabase_url.rstrip('/') + REST_BASE + "/setlists"
    headers = {
        "Authorization": f"Bearer {token}",
        "apikey": token,
        "Accept-Profile": "raw_data",
        "Prefer": "count=exact",
    }
    params = [("select", "external_id")]
    ids: Set[str] = set()
    range_from = 0
    while True:
        range_to = range_from + PAGE_SIZE - 1
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
    return ids


def load_csv_ids(csv_path: Path) -> Set[str]:
    ids: Set[str] = set()
    with csv_path.open(newline='', encoding='utf-8') as f:
        r = csv.DictReader(f)
        for row in r:
            eid = row.get('external_id')
            if eid:
                ids.add(str(eid))
    return ids


def main() -> None:
    preload_env_from_common_paths()
    supabase_url = os.environ.get("SUPABASE_URL", "").strip()
    service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    anon_key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    token = service_role_key or anon_key
    if not supabase_url or not token:
        raise RuntimeError("Missing SUPABASE_URL and/or SUPABASE_SERVICE_ROLE_KEY/ANON")

    csv_path = Path("setlists_external_ids.csv")
    if not csv_path.exists():
        raise FileNotFoundError(f"Missing CSV: {csv_path}")

    csv_ids = load_csv_ids(csv_path)
    bronze_ids = fetch_bronze_external_ids(supabase_url, token)

    only_in_csv = csv_ids - bronze_ids
    only_in_bronze = bronze_ids - csv_ids

    print(f"csv_unique={len(csv_ids)} bronze_unique={len(bronze_ids)}")
    print(f"only_in_csv={len(only_in_csv)} only_in_bronze={len(only_in_bronze)}")

    # Write samples to files for inspection
    Path("only_in_csv_sample.txt").write_text("\n".join(sorted(list(only_in_csv))[:200]), encoding="utf-8")
    Path("only_in_bronze_sample.txt").write_text("\n".join(sorted(list(only_in_bronze))[:200]), encoding="utf-8")
    print("Wrote samples: only_in_csv_sample.txt, only_in_bronze_sample.txt")


if __name__ == "__main__":
    main()
