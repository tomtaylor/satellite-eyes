# Overview

This project is a MacOS app called Satellite Eyes, which sets the user's desktop wallpaper to a map or satellite view for their current location.

It is a menu bar utility, targeting MacOS 13.0. This is a **macOS-only** app — do not use iOS Simulator tools to build or run it. Use `xcodebuild` directly.

## Build

The project uses an Xcode workspace with SwiftPM dependencies. The scheme is "Satellite Eyes".

```bash
# Build (Debug)
xcodebuild -workspace SatelliteEyes.xcworkspace -scheme "Satellite Eyes" -configuration Debug build

# Build (Release)
xcodebuild -workspace SatelliteEyes.xcworkspace -scheme "Satellite Eyes" -configuration Release build

# Clean
xcodebuild -workspace SatelliteEyes.xcworkspace -scheme "Satellite Eyes" clean
```

## Architecture

### Key Components

| File | Role |
|------|------|
| `AppDelegate.swift` | Entry point (`@main`), owns all managers and window controllers |
| `MapManager.swift` | Core orchestrator: location tracking (CLLocationManager), network monitoring (NWPathMonitor), preference observation (KVO on UserDefaults), wallpaper setting. Runs updates on a serial DispatchQueue |
| `MapImage.swift` | Fetches tile grid using async/await TaskGroup, composites into single image with CGContext, applies CIFilter chains, writes to disk |
| `MapTile.swift` | Models a single tile: URL construction from templates (`{x}`, `{y}`, `{z}`, `{q}` placeholders), coordinate math (Web Mercator projection) |
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

`SatelliteEyes/Locations.plist` (~3,400 entries) backs the "Interesting Sights" location modes. It is **generated, not hand-edited**. Categories: `airport`, `world_heritage_site`, `solar_farm`.

Scripts live in `data/scripts/`. They use PEP 723 inline metadata and no shebang, and derive their output paths from `__file__`, so they run from any directory:

```bash
# Refresh the solar farm list from a local OSM planet dump (~10 minutes)
uv run data/scripts/fetch_solar_farms.py /path/to/planet.osm.pbf

# Rebuild SatelliteEyes/Locations.plist from the CSVs in data/
uv run data/scripts/generate_locations.py
```

Rebuild the app afterwards so the bundle picks up the new plist.

- `data/airports.csv` (OurAirports) and `data/whc001.csv` (UNESCO World Heritage list) are raw upstream dumps, filtered at generate time.
- `data/solar_farms.csv` is pre-ranked output from `fetch_solar_farms.py`: the 1,000 largest solar plants by physical footprint, ranked by true polygon area, excluding sites tagged or named as not yet built.
- `fetch_solar_farms.py` reads a local planet `.osm.pbf` with DuckDB's `osmium` community extension (libosmium reconstructs the geometry, so areas and centroids come from spatial SQL). It takes the planet path as its argument and needs ~105 GB of scratch space beside that file for the node-location index, which it deletes on exit (`--index-path` moves it, `--count` changes how many farms are kept; `--help` for the rest). This is the one script with dependencies (`duckdb` and `typer`, declared in its PEP 723 block) and the one that takes arguments.
- Adding a category also needs a row in the "Location:" picker in `PreferencesWindowController.swift`, which hardcodes display names rather than reading `LocationStore.categories`.

## Conventions

- Pure Swift codebase. No Objective-C or bridging headers.
- SwiftUI for all window UI (Preferences, About, Manage Styles). AppKit for menu bar status item.
- Logging via `os.Logger` with subsystem `uk.co.tomtaylor.SatelliteEyes`.
- Tile fetching uses async/await with `TaskGroup` and a shared `URLSession` (4 concurrent connections per host).
- Multi-screen support: each screen gets its own wallpaper at appropriate resolution, with Retina detection for 2x tile sources.
- Only dependency is **Sparkle** (auto-updater) via SwiftPM.
