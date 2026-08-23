# Overview

This project is a MacOS app called Satellite Eyes, which sets the user's desktop wallpaper to a map or satellite view for their current location.

It is a menu bar utility, targeting MacOS 13.0. This is a **macOS-only** app — do not use iOS Simulator tools to build or run it. Use `xcodebuild` directly.

## Build

The project is a plain Xcode project with SwiftPM dependencies. The scheme is "Satellite Eyes".

```bash
# Build (Debug)
xcodebuild -project SatelliteEyes.xcodeproj -scheme "Satellite Eyes" -configuration Debug build

# Build (Release)
xcodebuild -project SatelliteEyes.xcodeproj -scheme "Satellite Eyes" -configuration Release build

# Clean
xcodebuild -project SatelliteEyes.xcodeproj -scheme "Satellite Eyes" clean
```

## Architecture

### Key Components

| File | Role |
|------|------|
| `AppDelegate.swift` | Entry point (`@main`), owns all managers and window controllers |
| `MapManager.swift` | Core orchestrator: location tracking (CLLocationManager), network monitoring (NWPathMonitor), preference observation (KVO on UserDefaults), wallpaper setting. `@MainActor`; updates are chained onto `updateTask` so they run one at a time |
| `MapImage.swift` | Sendable value type. Fetches tile grid using async/await TaskGroup, composites into single image with CGContext, applies CIFilter chains, writes to disk. `fetchTiles` is `@concurrent`, so this work never lands on the main actor. Also defines `ImageEffect`, the value-type form of a `Defaults.plist` filter chain |
| `MapTile.swift` | Models a single tile (a value type): URL construction from templates (`{x}`, `{y}`, `{z}`, `{q}` placeholders), coordinate math (Web Mercator projection) |
| `LocationStore.swift` | Loads bundled `Locations.plist` into `NamedLocation` values; supplies random locations by category |
| `StatusItemController.swift` | Menu bar icon with animation frames, dropdown menu, observes MapManager notifications for state |
| `PreferencesWindowController.swift` | SwiftUI preferences window (map style, zoom, effects, launch at login) |
| `ManageMapStylesWindowController.swift` | SwiftUI window for adding/removing custom map tile sources |
| `LoginItemManager.swift` | Launch at login via SMAppService |

### Communication Patterns

- **NotificationCenter**: MapManager posts `startedLoadNotification`, `finishedLoadNotification`, `failedLoadNotification`, `locationUpdatedNotification`, `locationLostNotification`, `locationPermissionDeniedNotification`. StatusItemController observes these.
- **KVO**: MapManager observes UserDefaults keys (`selectedMapTypeId`, `zoomLevel`, `selectedImageEffectId`) to trigger map refresh.

### Configuration

- **`BuiltInMapStyles.plist`**: The 12 built-in map tile sources — the source of truth for available map styles. Entry keys: `id`, `name`, `source` (tile URL template), optional `source2x`, `maxZoom`, `browserURL`, `upscaleRetina`, `logoImage`.
- **`Defaults.plist`**: The 9 image effects (`imageEffectTypes`, CIFilter chains), plus the scalar UserDefaults defaults.
- **`Locations.plist`**: Generated place list backing the "Interesting Sights" location modes. Do not edit by hand — see Data Pipeline below.
- **UserDefaults**: Runtime preferences (selected map type, zoom level 10-20, selected effect, location mode, rotation interval, cache cleanup flag).

## Data Pipeline

`SatelliteEyes/Locations.plist` (~4,400 entries) backs the "Interesting Sights" location modes. It is **generated, not hand-edited**. Categories: `airport`, `world_heritage_site`, `solar_farm`, `salt_pond_or_mine`.

Scripts live in `data/scripts/`. They use PEP 723 inline metadata and no shebang, and derive their output paths from `__file__`, so they run from any directory:

```bash
# Refresh every OSM-derived category from a local planet dump (~15 minutes)
uv run data/scripts/fetch_osm_areas.py /path/to/planet.osm.pbf

# Rebuild SatelliteEyes/Locations.plist from the CSVs in data/
uv run data/scripts/generate_locations.py
```

Rebuild the app afterwards so the bundle picks up the new plist.

- `data/airports.csv` (OurAirports) and `data/whc001.csv` (UNESCO World Heritage list) are raw upstream dumps, filtered at generate time.
- `data/solar_farms.csv` and `data/salt_ponds_and_mines.csv` are pre-ranked output from `fetch_osm_areas.py`: the 1,000 largest of each by true polygon footprint, excluding sites tagged or named as not yet built. The second combines `landuse=salt_pond`, `landuse=quarry` (the tag for surface extraction of any mineral, so open-pit mines as well as quarries) and `industrial=mine`, with a `kind` column recording which.
- `fetch_osm_areas.py` reads a local planet `.osm.pbf` with DuckDB's `osmium` community extension (libosmium reconstructs the geometry, so areas and centroids come from spatial SQL). It takes the planet path as its argument and needs ~105 GB of scratch space beside that file for the node-location index, which it deletes on exit (`--index-path` moves it, `--count` changes how many are kept per category; `--help` for the rest). This is the one script with dependencies (`duckdb` and `typer`, declared in its PEP 723 block) and the one that takes arguments.
- Add a category by appending to `CATEGORIES` in `fetch_osm_areas.py`. Every category is read from one connection so the node index is built once, but each needs its own query: the extension only pushes tag filters into the scan when they are a plain AND, or an OR over one key, and without pushdown it builds geometry for every area on the planet.
- Adding a category also needs a row in the "Location:" picker in `PreferencesWindowController.swift`, which hardcodes display names rather than reading `LocationStore.categories`.

## Conventions

- Pure Swift codebase. No Objective-C or bridging headers.
- **Swift 6 language mode** (`SWIFT_VERSION = 6.0`), so strict concurrency checking is on and data races are compile errors. The UI classes and `MapManager` are `@MainActor`; only tile fetching and image compositing run off it, on `Sendable` value types. Don't turn on `SWIFT_APPROACHABLE_CONCURRENCY` without checking `MapImage`: it enables `NonisolatedNonsendingByDefault`, which would otherwise pull that work back onto the main actor.
- SwiftUI for all window UI (Preferences, About, Manage Styles). AppKit for menu bar status item.
- Logging via `os.Logger` with subsystem `uk.co.tomtaylor.SatelliteEyes`.
- Tile fetching uses async/await with `TaskGroup` and a shared `URLSession` (4 concurrent connections per host).
- Multi-screen support: each screen gets its own wallpaper at appropriate resolution, with Retina detection for 2x tile sources.
- Only dependency is **Sparkle** (auto-updater) via SwiftPM.
