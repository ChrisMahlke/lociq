# Architecture

Lociq is a single-surface SwiftUI iPhone app. The product goal is to show one quiet city profile without exposing data-source machinery to the user.

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

## Responsibilities

- `ContentView` owns root composition, summary/details toggling, the first reveal sequence, and routing of typed actions.
- `LocationProfileViewModel` owns permission, location, cache, and async load state. It also runs refresh (locate first, then reload) and publishes refresh outcomes.
- `LocationProfileViewStateMapper` projects the state machine into view values: the snapshot with its status line, the primary action, the refresh control, and pull-to-refresh availability. Views never compare display strings.
- `ProfileLoadPlanner` decides whether a fix needs a load. A profile stays valid while the user is still in its place and it was built from the current data vintage.
- `CityProfileCacheStore` persists the last successful profile as a file in Application Support.
- `CensusCityProfileLoader` converts service results into loaded or explained unavailable outcomes and bounds the whole load.
- `CensusCityProfileService` geocodes every request and memoizes statistics by place GEOID for the app session. A forced refresh skips the memo.
- `CensusServiceGraph` builds the geocoder, ACS, and TIGER clients once, so every path shares one set of session caches.
- `ACSDemographicsMapper` is the only place that maps ACS variable codes to domain fields.
- `GeoJSONBoundaryPathBuilder` builds the boundary glyph: polygons with holes, fitted to the part that contains the user, in unit space.

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
