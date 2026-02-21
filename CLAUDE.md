# Overview

This project is a MacOS app called Satellite Eyes, which sets the user's desktop wallpaper to a map or satellite view for their current location.

It is a menu bar utility, targeting MacOS 13.0.

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
| `StatusItemController.swift` | Menu bar icon with animation frames, dropdown menu, observes MapManager notifications for state |
| `PreferencesWindowController.swift` | SwiftUI preferences window (map style, zoom, effects, launch at login) |
| `ManageMapStylesWindowController.swift` | SwiftUI window for adding/removing custom map tile sources |
| `LoginItemManager.swift` | Launch at login via SMAppService |

### Communication Patterns

- **NotificationCenter**: MapManager posts `startedLoadNotification`, `finishedLoadNotification`, `failedLoadNotification`, `locationUpdatedNotification`, `locationLostNotification`, `locationPermissionDeniedNotification`. StatusItemController observes these.
- **KVO**: MapManager observes UserDefaults keys (`selectedMapTypeId`, `zoomLevel`, `selectedImageEffectId`) to trigger map refresh.

### Configuration

- **`Defaults.plist`**: Defines 15 built-in map tile sources and 9 image effects (CIFilter chains). This is the source of truth for available map styles and effects.
- **UserDefaults**: Runtime preferences (selected map type, zoom level 10-20, selected effect, cache cleanup flag).

## Conventions

- Pure Swift codebase. No Objective-C or bridging headers.
- SwiftUI for all window UI (Preferences, About, Manage Styles). AppKit for menu bar status item.
- Logging via `os.Logger` with subsystem `uk.co.tomtaylor.SatelliteEyes`.
- Tile fetching uses async/await with `TaskGroup` and a shared `URLSession` (4 concurrent connections per host).
- Multi-screen support: each screen gets its own wallpaper at appropriate resolution, with Retina detection for 2x tile sources.
- Only dependency is **Sparkle** (auto-updater) via SwiftPM.
