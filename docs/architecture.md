# Architecture

Lociq is a single-surface SwiftUI app for iPhone, iPad, and Apple Watch. The product goal is to show one quiet city profile without exposing data-source machinery to the user.

## Targets And Folders

| Folder | Compiled into | Contents |
| --- | --- | --- |
| `Lociq/` | Lociq (iPhone and iPad) | App entry, `ContentView`, the iOS views, layout, menu commands, and appearance |
| `Shared/` | Lociq, LociqWatch (LociqWatchWidgets compiles only `ComplicationSnapshot.swift` and `SpokenText.swift`) | Models, Census services, the state machine, cache, formatting, the boundary glyph, the palette, the complication record, and the privacy manifest |
| `LociqWatch/` | LociqWatch | The Apple Watch app |
| `WatchComplications/` | LociqWatch, LociqWatchWidgets | Complication content and views |
| `LociqWatchWidgets/` | LociqWatchWidgets | The widget bundle and its timeline provider |

The folders are Xcode synchronized folders: a file added to a folder joins that folder's targets, except that the widget extension takes only the two dependency-free files it needs from `Shared/`, so it links no location or network code. Code in `Shared/` must compile for iOS 16 and watchOS 10, so UIKit-only calls are wrapped in `#if os(iOS)`. The watch app is embedded in the iOS app, and the widget extension in the watch app, so building or archiving the `Lociq` scheme builds all three.

## Runtime Flow

```mermaid
sequenceDiagram
    participant UI as ContentView
    participant VM as LocationProfileViewModel
    participant Planner as ProfileLoadPlanner
    participant Loader as CensusCityProfileLoader
    participant Service as CensusCityProfileService
    participant Census as Census APIs
    participant Cache as CityProfileCacheStore

    UI->>VM: initialize StateObject
    VM->>Cache: load last profile (file; migrates the old UserDefaults payload once)
    Cache-->>VM: cached profile, labeled by location access
    UI->>VM: activate
    VM->>Planner: decide(fix, displayed profile)
    Planner-->>VM: keep (same place, current data) or load
    VM->>Loader: loadProfile(request) within a 25-second budget
    Loader->>Service: fetchPlaceProfile(options)
    Service->>Census: geocoder, then ACS/TIGER by place GEOID (memoized per place)
    Census-->>Service: profile pieces
    Service-->>Loader: ResolvedCityProfile
    Loader-->>VM: loaded or an explained unavailable state
    VM->>Cache: save successful profile (off the main actor)
    VM->>VM: build the boundary glyph off the main actor
    UI->>VM: read viewState, boundaryGlyph, traceToken, refreshEvent
```

The watch app runs the same flow with the watch's own location and its own cache.

## Responsibilities

- `ContentView` owns root composition, summary/details toggling, the first reveal sequence, and routing of typed actions.
- `MinimalLayout` chooses the canvas for the window (phone, large, or spread) and scales type, spacing, and the boundary for it.
- `LociqCommands` puts Summary, Details, Refresh, and Appearance in the iPad menu bar, with keyboard shortcuts.
- `LocationProfileViewModel` owns permission, location, cache, and async load state. It also runs refresh (locate first, then reload) and publishes refresh outcomes.
- `LocationProfileViewStateMapper` projects the state machine into view values: the snapshot with its status line, the primary action, the refresh control, and pull-to-refresh availability. Views never compare display strings.
- `ProfileLoadPlanner` decides whether a fix needs a load. A profile stays valid while the user is still in its place and it was built from the current data vintage.
- `CityProfileCacheStore` persists the last successful profile as a file in Application Support.
- `CensusCityProfileLoader` converts service results into loaded or explained unavailable outcomes and bounds the whole load.
- `CensusCityProfileService` geocodes every request and memoizes statistics by place GEOID for the app session. A forced refresh skips the memo.
- `CensusServiceGraph` builds the geocoder, ACS, and TIGER clients once, so every path shares one set of session caches.
- `ACSDemographicsMapper` is the only place that maps ACS variable codes to domain fields.
- `GeoJSONBoundaryPathBuilder` builds the boundary glyph: polygons with holes, fitted to the part that contains the user, in unit space.
- `WatchRootView` routes the watch app between its waiting, message, and profile screens, writes the complication record, and reloads the complications.
- `ComplicationSnapshot` is the complication record. The watch app builds it from what it shows (`ComplicationSnapshotBuilder.swift`); the widget only reads it.

## iPad

`MinimalLayout` picks one of three canvases from the window size:

- **Phone**, for windows narrower than 600 pt or shorter than 500 pt: every iPhone, Slide Over, and narrow Split View. The original composition, unchanged.
- **Large**, for other iPad windows: the same composition, grown to the window by `canvasScale` (1 to 1.45, from the window's size relative to 700 x 820 pt). Display type grows fully, body text by 80%, captions by 60%, and spacing follows the window's height. The growth fades out as the user's text size grows, so the accessibility sizes match iPhone and text never gets smaller when text size grows.
- **Spread**, for wide windows (13-inch and 11-inch iPads in landscape) at least 720 pt tall, at standard text sizes: the details sit in a quieter column beside the city and its summary, so the summary/details toggle is not needed.

Two columns stay until the accessibility sizes on large canvases, and at every size on windows 1,000 pt or wider. The menu bar and keyboard offer Summary (⌘1), Details (⌘2), Refresh (⌘R), and Appearance, and the bottom controls highlight under the pointer.

## Apple Watch

The watch app is independent: it asks for its own location permission, finds the watch's location, and loads Census data itself, so it works without the iPhone nearby. It drives the same `LocationProfileViewModel` as the iPhone app, so freshness, labels, failures, and refresh behave the same.

A loaded city is four vertical pages, turned with the Digital Crown: the place (outline, name, density), people (population, income, households), homes and education (with their bars), and the details with the source and the Census Data API notice. watchOS apps cannot open Settings, so when location is off the watch says where to allow it instead of showing a button.

The complications and Smart Stack widget show the city, its outline, and its population. They cannot locate the wearer and never call the Census services. They read a small record, `ComplicationSnapshot`, that the watch app writes to the App Group container `group.io.chrismahlke.lociq` whenever it shows a definite answer about where the wearer is: the current city, with its name, population, and an outline simplified for complication sizes, or a place without city data, such as outside city limits. A saved city that may not be current, location that is off, and failures write nothing, so the last record keeps its time. The record holds no coordinates, and the complications never draw the location dot. Every family says when the record was true: the rectangular family always ("AS OF 9:41 AM"), and the others show the date in place of the population once that day has passed.

## Freshness

Freshness is defined by place and data vintage, not by the clock. ACS 5-year estimates change once a year, so a stationary user's profile never needs reloading:

- A fix within 250 m of the profile's lookup point, or clearly inside its boundary, keeps the profile. The marker moves; nothing is requested.
- A fix outside the place loads the new place. The old city stays dimmed with "UPDATING FOR NEW LOCATION" meanwhile.
- A profile from an older data vintage or snapshot format reloads at the next fix.

The status line says when the city shown may not be the user's current place: "LAST LOCATION", "SAVED CITY · LOCATION OFF", "LAST KNOWN AREA", "LAST KNOWN AREA · NOT YOUR CURRENT LOCATION", or "SAVED · OFFLINE".

## Failure Design

Failures are typed, and each has a plain-language message:

| Failure | Message | Retry |
| --- | --- | --- |
| Network unavailable | "OFFLINE" / "CHECK CONNECTION" | Yes |
| Service timeout or the 25-second load budget | "NO RESPONSE" / "CENSUS SERVICE TIMED OUT" | Yes |
| Census service error | "CENSUS SERVICE" / "TEMPORARILY UNAVAILABLE" | Yes |
| No incorporated place or CDP | "OUTSIDE CITY LIMITS" / county name | No |
| No county and no place | "OUTSIDE U.S. COVERAGE" | No |
| Place without ACS estimates | city / "NO CENSUS ESTIMATES FOR THIS PLACE YET" | No |
| Missing Census API key | "DATA SERVICE UNAVAILABLE" | No (a build problem) |

Location problems have their own states: a denial routes to Settings, a restriction offers no action, and a missing fix after two attempts or 15 seconds offers Retry.

Partial failures are allowed. If ACS demographics succeed and TIGER geometry fails, the app shows the city values without the boundary (and without density, which needs the boundary's land area). If a refresh fails while a profile is visible, the profile stays visible and the status line says so.

## Persisted Schema

`CachedCityProfile`, `DemographicSnapshot`, `DemographicMetric`, `DemographicDetailRow`, the GeoJSON models, and `CityProfileLoadFailure` are persisted. Change them by adding optional fields only, and keep existing keys and enum cases readable. `LociqTests.decodes1_3_0CachePayload` pins a payload written by an earlier build. Bump `CachedCityProfile.currentFormatVersion` when a formatting fix should reach cached profiles.
