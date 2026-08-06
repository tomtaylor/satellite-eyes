# /// script
# requires-python = ">=3.12"
# ///

import csv
import plistlib
import re
from pathlib import Path

data_dir = Path(__file__).resolve().parent.parent
repo_root = data_dir.parent
airports_csv_path = data_dir / "airports.csv"
whc_csv_path = data_dir / "whc001.csv"
plist_path = repo_root / "SatelliteEyes" / "Locations.plist"

# Categories written by fetch_osm_areas.py, which share a column layout.
osm_area_categories = {
    "solar_farms.csv": "solar_farm",
    "salt_ponds_and_mines.csv": "salt_pond_or_mine",
}

locations = []

with airports_csv_path.open(newline="") as f:
    for row in csv.DictReader(f):
        if row["type"] == "large_airport":
            locations.append(
                {
                    "name": row["name"],
                    "category": "airport",
                    "latitude": float(row["latitude_deg"]),
                    "longitude": float(row["longitude_deg"]),
                }
            )

with whc_csv_path.open(newline="", encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        coords = row["Coordinates"]
        if not coords:
            continue
        lat, lon = coords.split(",", 1)
        locations.append(
            {
                "name": re.sub(r"<[^>]+>", "", row["Name EN"]),
                "category": "world_heritage_site",
                "latitude": float(lat),
                "longitude": float(lon),
            }
        )

for filename, category in osm_area_categories.items():
    with (data_dir / filename).open(newline="") as f:
        for row in csv.DictReader(f):
            locations.append(
                {
                    "name": row["name"],
                    "category": category,
                    "latitude": float(row["latitude"]),
                    "longitude": float(row["longitude"]),
                }
            )

plist_path.parent.mkdir(parents=True, exist_ok=True)
with plist_path.open("wb") as f:
    plistlib.dump(locations, f)

print(f"Wrote {len(locations)} locations to {plist_path}")
