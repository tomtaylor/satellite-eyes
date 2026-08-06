# /// script
# requires-python = ">=3.12"
# dependencies = ["duckdb>=1.5", "typer>=0.12"]
# ///

"""Extract the largest OpenStreetMap areas backing the "Interesting Sights" modes.

Reads a local planet dump with DuckDB's `osmium` community extension, which uses
libosmium to reconstruct geometry: closed ways and multipolygon relations arrive
as ready-made Polygons and MultiPolygons, so true footprint areas and
area-weighted centroids come straight from spatial SQL.

Reading the planet locally is what lets this be a single pass per category: every
candidate gets an exact area at once, so ranking is a plain sort. A remote API
such as Overpass cannot sort by size server-side, and would need a bounding-box
pass followed by geometry re-fetches of the best candidates before the cutoff
could be trusted.

Every category is read from one connection, because the node location index is
what costs the runtime and DuckDB caches it for the life of the connection. Each
category still gets its own query rather than one combined filter, so that its
tags push down into the scan; an OR across differing keys would not, and the
extension would then build geometry for every area on the planet.

Takes the planet file as its argument. Building the index needs ~105 GB of
scratch space and dominates the runtime; it is deleted afterwards, as the
extension rebuilds it per process anyway.

Writes one CSV per category into data/, consumed by generate_locations.py.
"""

import csv
import re
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated, Callable, Optional

import duckdb
import typer

TARGET_COUNT = 1000

data_dir = Path(__file__).resolve().parent.parent

TAG_RE = re.compile(r"<[^>]+>")
CAPACITY_RE = re.compile(r"^\s*([0-9]+(?:\.[0-9]+)?)\s*([kKmMgG]?)[wW]\s*$")
CAPACITY_MULTIPLIERS_MW = {"": 1e-6, "k": 1e-3, "m": 1.0, "g": 1000.0}

# Unbuilt sites are bare ground from above, so they make poor wallpaper. OSM's
# lifecycle prefixes (construction:power=plant) already fall outside these
# queries, but in practice several of the largest sites are tagged plain
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
# resource= is free text in principle, so only take the tidy values.
RESOURCE_RE = re.compile(r"^[a-z][a-z_]{2,20}$")
CURRENT_YEAR = time.gmtime().tm_year


# MARK: - Categories


def capacity_mw(tags):
    match = CAPACITY_RE.match(tags.get("plant:output:electricity", ""))
    if not match:
        return ""
    value, prefix = match.groups()
    return round(float(value) * CAPACITY_MULTIPLIERS_MW[prefix.lower()], 3)


def extraction_kind(tags):
    """Which of the three things a salt-pond-or-mine row actually is."""
    if tags.get("landuse") == "salt_pond":
        return "salt_pond"
    if tags.get("landuse") == "quarry":
        return "quarry"
    return "mine"


def extraction_noun(tags):
    """Lowercase noun for a salt pond or mine, e.g. "gold mine", "sand quarry".

    Most quarries and mines this size are unnamed in OSM, so what resource= says
    is being dug out is usually the only description available.
    """
    kind = extraction_kind(tags)
    if kind == "salt_pond":
        return "salt pond"

    noun = "quarry" if kind == "quarry" else "mine"
    # resource is often a ;-separated list; the first entry is the main one.
    resource = tags.get("resource", "").split(";")[0].strip()
    if RESOURCE_RE.match(resource) and resource not in ("unknown", "yes", "none"):
        return f"{resource.replace('_', ' ')} {noun}"
    return noun


@dataclass(frozen=True)
class Category:
    label: str
    filename: str
    predicate: str
    # Used to name sites OSM left unnamed, which is most of the quarries.
    # The two differ: an unnamed plant reads "Solar farm near 1.2, 3.4", but one
    # with only an operator reads "Iberdrola solar plant".
    unnamed_label: Callable[[dict], str]
    operator_noun: Callable[[dict], str]
    # (header, tags -> value) pairs appended to the CSV after the shared columns.
    extra_columns: tuple = ()


CATEGORIES = (
    Category(
        label="solar farms",
        filename="solar_farms.csv",
        predicate="tags['power'] = 'plant' AND tags['plant:source'] = 'solar'",
        unnamed_label=lambda tags: "Solar farm",
        operator_noun=lambda tags: "solar plant",
        extra_columns=(("capacity_mw", capacity_mw),),
    ),
    Category(
        label="salt ponds and mines",
        filename="salt_ponds_and_mines.csv",
        # landuse=quarry is the tag for surface extraction of any mineral, so it
        # covers open-pit mines as well as quarries proper; industrial=mine adds
        # the sites mapped as industrial landuse instead. landuse=mine is
        # deprecated and appears only on nodes, which have no footprint.
        predicate=(
            "tags['landuse'] IN ('salt_pond', 'quarry') OR tags['industrial'] = 'mine'"
        ),
        unnamed_label=lambda tags: extraction_noun(tags).capitalize(),
        operator_noun=extraction_noun,
        extra_columns=(("kind", extraction_kind),),
    ),
)


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
      AND ({predicate})
"""

COLUMNS = ["kind", "type", "id", "tags", "refs", "ref_types", "area", "latitude", "longitude"]


def sql_literal(value):
    return str(value).replace("'", "''")


def open_planet(index_path):
    """A connection set up to read a planet dump, index cached for its lifetime."""
    connection = duckdb.connect()
    connection.execute("INSTALL spatial; LOAD spatial;")
    connection.execute("INSTALL osmium FROM community; LOAD osmium;")

    # Geometry is lon/lat, so tell spatial not to assume lat/lon for the
    # spheroid measures. A planet-wide node index cannot fit in memory, so
    # push it to a file beside the planet dump.
    connection.execute("SET geometry_always_xy = true")
    connection.execute("SET osmium_index_type = 'dense_file_array'")
    connection.execute(f"SET osmium_index_path = '{sql_literal(index_path)}'")
    return connection


def fetch_areas(connection, planet_path, category):
    """Every area matching the category, with its footprint and centroid."""
    query = QUERY.format(planet=sql_literal(planet_path), predicate=category.predicate)
    return [dict(zip(COLUMNS, row)) for row in connection.execute(query).fetchall()]


def has_geometry(area):
    return area["area"] and area["area"] > 0 and area["latitude"] is not None


def merge_site_relations(areas):
    """Fold type=site relations into one entry covering their member areas.

    A site relation is a bag of separately mapped polygons rather than a
    multipolygon, so libosmium builds no geometry for it. Its members are
    themselves tagged as the thing in question, though, so they are already in
    the result — combining them here both recovers the parent (Kenhardt, for
    one, is only large enough for the list once its five blocks are summed) and
    stops those blocks being counted a second time on their own.
    """
    by_key = {(a["type"], a["id"]): a for a in areas if a["kind"] == "area" and has_geometry(a)}
    merged = []

    for site in areas:
        if site["kind"] != "relation":
            continue

        keys = [
            ("way", ref)
            for ref, ref_type in zip(site["refs"] or [], site["ref_types"] or [])
            if ref_type == "way"
        ]
        members = [by_key.pop(key) for key in keys if key in by_key]
        area = sum(member["area"] for member in members)
        if area <= 0:
            continue

        # Weight each block's centroid by its own area. Sites are routinely
        # mapped as many scattered blocks, so centring on any single one lands
        # kilometres from where the interesting part is.
        merged.append(
            {
                **site,
                "area": area,
                "latitude": sum(m["area"] * m["latitude"] for m in members) / area,
                "longitude": sum(m["area"] * m["longitude"] for m in members) / area,
            }
        )

    return list(by_key.values()) + merged


# MARK: - Tags


def resolve_name(tags, latitude, longitude, category):
    for key in ("name", "name:en"):
        if tags.get(key):
            return TAG_RE.sub("", tags[key]).strip()
    if tags.get("operator"):
        return f"{TAG_RE.sub('', tags['operator']).strip()} {category.operator_noun(tags)}"
    return f"{category.unnamed_label(tags)} near {latitude:.3f}, {longitude:.3f}"


def is_built(tags):
    """False when anything about the tagging says the site isn't finished yet."""
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


# MARK: - Output


def write_csv(category, top):
    csv_path = data_dir / category.filename
    csv_path.parent.mkdir(parents=True, exist_ok=True)

    with csv_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            ["osm_type", "osm_id", "name", "latitude", "longitude", "area_m2"]
            + [header for header, _ in category.extra_columns]
        )
        for area in top:
            latitude, longitude = area["latitude"], area["longitude"]
            writer.writerow(
                [
                    area["type"],
                    area["id"],
                    resolve_name(area["tags"], latitude, longitude, category),
                    f"{latitude:.6f}",
                    f"{longitude:.6f}",
                    round(area["area"]),
                ]
                + [value(area["tags"]) for _, value in category.extra_columns]
            )

    return csv_path


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
        int, typer.Option("--count", min=1, help="How many of the largest to keep per category.")
    ] = TARGET_COUNT,
):
    """Write the largest areas in PLANET to one CSV per category under data/."""
    index_path = index_path or planet.with_name("osmium-node-index.bin")

    print(f"Reading {planet.name}...")
    print(f"  Building the node location index at {index_path}; this takes a few minutes")
    try:
        connection = open_planet(index_path)
        for category in CATEGORIES:
            print(f"Searching for {category.label}...")
            areas = fetch_areas(connection, planet, category)
            print(f"  Found {len(areas)}")

            areas = merge_site_relations(areas)
            built = [area for area in areas if is_built(area["tags"])]
            print(f"  Skipped {len(areas) - len(built)} tagged or named as not yet built")

            built.sort(key=lambda area: area["area"], reverse=True)
            top = built[:count]
            if len(top) < count:
                raise SystemExit(f"Only {len(top)} {category.label} found, need {count}")

            csv_path = write_csv(category, top)
            smallest = round(top[-1]["area"] / 10_000)
            largest = round(top[0]["area"] / 10_000)
            print(f"  Wrote {len(top)} to {csv_path} ({largest} down to {smallest} hectares)")
        connection.close()
    finally:
        index_path.unlink(missing_ok=True)


typer.run(main)
