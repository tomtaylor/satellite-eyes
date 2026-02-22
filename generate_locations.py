# /// script
# requires-python = ">=3.12"
# ///

import csv
import plistlib
import re
from pathlib import Path

script_dir = Path(__file__).resolve().parent
airports_csv_path = script_dir / "data" / "airports.csv"
whc_csv_path = script_dir / "data" / "whc001.csv"
plist_path = script_dir / "SatelliteEyes" / "Locations.plist"

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

plist_path.parent.mkdir(parents=True, exist_ok=True)
with plist_path.open("wb") as f:
    plistlib.dump(locations, f)

print(f"Wrote {len(locations)} locations to {plist_path}")
