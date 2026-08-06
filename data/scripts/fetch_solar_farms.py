# /// script
# requires-python = ">=3.12"
# dependencies = ["duckdb>=1.5", "typer>=0.12"]
# ///

"""Extract the largest solar farms from a local OpenStreetMap planet dump.

Reads planet.osm.pbf with DuckDB's `osmium` community extension, which uses
libosmium to reconstruct geometry: closed ways and multipolygon relations
arrive as ready-made Polygons and MultiPolygons, so true footprint areas and
area-weighted centroids come straight from spatial SQL.

Reading the planet locally is what lets this be a single pass: every plant gets
an exact area at once, so ranking is a plain sort. A remote API such as Overpass
cannot sort by size server-side, and would need a bounding-box pass followed by
geometry re-fetches of the best candidates before the cutoff could be trusted.

Takes the planet file as its argument. Building the node-location index needs
~105 GB of scratch space and dominates the ~10 minute runtime; it is deleted
afterwards, as the extension rebuilds it per process anyway.

Output is data/solar_farms.csv, consumed by generate_locations.py.
"""

import csv
import re
import time
from pathlib import Path
from typing import Annotated, Optional

import duckdb
import typer

TARGET_COUNT = 1000

data_dir = Path(__file__).resolve().parent.parent
csv_path = data_dir / "solar_farms.csv"

TAG_RE = re.compile(r"<[^>]+>")
CAPACITY_RE = re.compile(r"^\s*([0-9]+(?:\.[0-9]+)?)\s*([kKmMgG]?)[wW]\s*$")
CAPACITY_MULTIPLIERS_MW = {"": 1e-6, "k": 1e-3, "m": 1.0, "g": 1000.0}

# Unbuilt plants are bare ground from above, so they make poor wallpaper. OSM's
# lifecycle prefixes (construction:power=plant) already fall outside this
# script's query, but in practice several of the largest sites are tagged plain
# power=plant while only their name or note says they aren't finished — so check
# free text as well as the structured tags.
LIFECYCLE_KEYS = ("construction", "proposed")
LIFECYCLE_TEXT_KEYS = ("name", "name:en", "note", "description", "operational_status")
NOT_BUILT_RE = re.compile(
    r"under construction|in construction|under development"
    r"|\bproposed\b|\bplanned\b"
    r"|تحت الانشاء|تحت الإنشاء"
    r"|在建|施工中"
    r"|im bau|en construcción|en construction",
    re.IGNORECASE,
)
START_YEAR_RE = re.compile(r"^(\d{4})")
CURRENT_YEAR = time.gmtime().tm_year


# MARK: - Planet query


# `kind` distinguishes what libosmium built, not the OSM type: 'area' covers
# closed ways and multipolygon relations alike, both carrying real geometry.
# Every other relation type (overwhelmingly type=site) comes back as 'relation'
# with NULL geometry and a member list, and is stitched together below.
QUERY = """
    SELECT kind,
           type,
           id,
           tags,
           refs,
           ref_types,
           ST_Area_Spheroid(geometry) AS area,
           ST_Y(ST_Centroid(geometry)) AS latitude,
           ST_X(ST_Centroid(geometry)) AS longitude
    FROM osmium_read('{planet}')
    WHERE kind IN ('area', 'relation')
      AND tags['power'] = 'plant'
      AND tags['plant:source'] = 'solar'
"""


def sql_literal(value):
    return str(value).replace("'", "''")


def fetch_plants(planet_path, index_path):
    """Every solar power plant in the planet file, with area and centroid."""
    connection = duckdb.connect()
    connection.execute("INSTALL spatial; LOAD spatial;")
    connection.execute("INSTALL osmium FROM community; LOAD osmium;")

    # Geometry is lon/lat, so tell spatial not to assume lat/lon for the
    # spheroid measures. A planet-wide node index cannot fit in memory, so
    # push it to a file beside the planet dump.
    connection.execute("SET geometry_always_xy = true")
    connection.execute("SET osmium_index_type = 'dense_file_array'")
    connection.execute(f"SET osmium_index_path = '{sql_literal(index_path)}'")

    columns = ["kind", "type", "id", "tags", "refs", "ref_types", "area", "latitude", "longitude"]
    rows = connection.execute(QUERY.format(planet=sql_literal(planet_path))).fetchall()
    connection.close()
    return [dict(zip(columns, row)) for row in rows]


def has_geometry(plant):
    return plant["area"] and plant["area"] > 0 and plant["latitude"] is not None


def merge_site_relations(plants):
    """Fold type=site relations into one plant covering their member areas.

    A site relation is a bag of separately mapped polygons rather than a
    multipolygon, so libosmium builds no geometry for it. Its members are
    themselves tagged as solar plants, though, so they are already in the
    result — combining them here both recovers the parent (Kenhardt, for one,
    is only large enough for the list once its five blocks are summed) and
    stops those blocks being counted a second time on their own.
    """
    areas = {(p["type"], p["id"]): p for p in plants if p["kind"] == "area" and has_geometry(p)}
    merged = []

    for site in plants:
        if site["kind"] != "relation":
            continue

        keys = [
            ("way", ref)
            for ref, ref_type in zip(site["refs"] or [], site["ref_types"] or [])
            if ref_type == "way"
        ]
        members = [areas.pop(key) for key in keys if key in areas]
        area = sum(member["area"] for member in members)
        if area <= 0:
            continue

        # Weight each block's centroid by its own area. Plants are routinely
        # mapped as many scattered blocks, so centring on any single one lands
        # kilometres from where the panels actually are.
        merged.append(
            {
                **site,
                "area": area,
                "latitude": sum(m["area"] * m["latitude"] for m in members) / area,
                "longitude": sum(m["area"] * m["longitude"] for m in members) / area,
            }
        )

    return list(areas.values()) + merged


# MARK: - Tags


def resolve_name(tags, latitude, longitude):
    for key in ("name", "name:en"):
        if tags.get(key):
            return TAG_RE.sub("", tags[key]).strip()
    if tags.get("operator"):
        return f"{TAG_RE.sub('', tags['operator']).strip()} solar plant"
    return f"Solar farm near {latitude:.3f}, {longitude:.3f}"


def is_built(tags):
    """False when anything about the tagging says the plant isn't finished yet."""
    for key in LIFECYCLE_KEYS:
        if tags.get(key, "no") != "no":
            return False

    for key in LIFECYCLE_TEXT_KEYS:
        if NOT_BUILT_RE.search(tags.get(key, "")):
            return False

    start_year = START_YEAR_RE.match(tags.get("start_date", ""))
    if start_year and int(start_year.group(1)) > CURRENT_YEAR:
        return False

    return True


def capacity_mw(tags):
    match = CAPACITY_RE.match(tags.get("plant:output:electricity", ""))
    if not match:
        return ""
    value, prefix = match.groups()
    return round(float(value) * CAPACITY_MULTIPLIERS_MW[prefix.lower()], 3)


# MARK: - Main


def main(
    planet: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="OpenStreetMap planet dump to read (.osm.pbf).",
        ),
    ],
    index_path: Annotated[
        Optional[Path],
        typer.Option(
            "--index-path",
            dir_okay=False,
            help=(
                "Where to build the ~105 GB node location index. "
                "Defaults to sitting beside the planet file. Deleted on exit."
            ),
        ),
    ] = None,
    count: Annotated[
        int, typer.Option("--count", min=1, help="How many of the largest farms to keep.")
    ] = TARGET_COUNT,
):
    """Write the largest solar farms in PLANET to data/solar_farms.csv."""
    index_path = index_path or planet.with_name("osmium-node-index.bin")

    print(f"Reading solar power plants from {planet.name}...")
    print(f"  Building the node location index at {index_path}; this takes a few minutes")
    try:
        plants = fetch_plants(planet, index_path)
    finally:
        index_path.unlink(missing_ok=True)

    print(f"Found {len(plants)} solar plants")
    plants = merge_site_relations(plants)

    built = [plant for plant in plants if is_built(plant["tags"])]
    print(f"  Skipped {len(plants) - len(built)} plants tagged or named as not yet built")

    built.sort(key=lambda plant: plant["area"], reverse=True)
    top = built[:count]

    if len(top) < count:
        raise SystemExit(f"Only {len(top)} plants found, need {count}")

    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            ["osm_type", "osm_id", "name", "latitude", "longitude", "area_m2", "capacity_mw"]
        )
        for farm in top:
            latitude, longitude = farm["latitude"], farm["longitude"]
            writer.writerow(
                [
                    farm["type"],
                    farm["id"],
                    resolve_name(farm["tags"], latitude, longitude),
                    f"{latitude:.6f}",
                    f"{longitude:.6f}",
                    round(farm["area"]),
                    capacity_mw(farm["tags"]),
                ]
            )

    smallest = round(top[-1]["area"] / 10_000)
    largest = round(top[0]["area"] / 10_000)
    print(f"Wrote {len(top)} solar farms to {csv_path} ({largest} down to {smallest} hectares)")


typer.run(main)
