# Architecture

Lociq is a single-surface SwiftUI iPhone app. The product goal is to show one quiet city profile without exposing data-source machinery to the user.

## Runtime Flow

```mermaid
sequenceDiagram
    participant UI as ContentView
    participant VM as LocationProfileViewModel
    participant Mapper as LocationProfileViewStateMapper
    participant Loader as CensusCityProfileLoader
    participant Service as CensusCityProfileService
    participant Census as Census APIs
    participant Cache as CityProfileCacheStore

    UI->>VM: initialize StateObject
    VM->>Cache: load last profile
    Cache-->>VM: cached profile, if present
    UI->>VM: activate
    VM->>Loader: loadProfile(coordinate) when authorized/location available
    Loader->>Service: fetchPlaceProfile
    Service->>Census: geocoder, then ACS/TIGER by place ID
    Census-->>Service: profile pieces
    Service-->>Loader: ResolvedCityProfile
    Loader-->>VM: loaded or unavailable
    VM->>Cache: save successful profile
    UI->>VM: read snapshot, boundary, and flags
    VM->>Mapper: project state
    Mapper-->>VM: view-facing values
    VM-->>UI: computed display properties
```

## Responsibilities

- `ContentView` owns only root composition, summary/details toggling, and the first reveal sequence.
- `LocationProfileViewModel` owns permission, location, cache, and async load state.
- `LocationProfileViewStateMapper` projects the state machine into simple view values exposed through ViewModel computed properties, so SwiftUI does not need to understand loading internals.
- `CityProfileCacheStore` persists the last successful profile.
- `CensusCityProfileLoader` converts service results into UI-ready load outcomes.
- `CensusCityProfileService` memoizes successful demographic coordinate lookups during the app session.
- `DirectCensusCityProfileClient` composes geocoder, ACS, and TIGER clients.
- `ACSDemographicsMapper` is the only place that maps ACS variable codes to domain fields.
- `GeoJSONBoundaryPathBuilder` handles Web Mercator projection and display scaling for the outline.

## Failure Design

Failures are intentionally typed:

- network unavailable
- service timeout
- no city match
- no ACS demographic data
- no TIGER boundary
- missing Census API key

Partial failures are allowed. If ACS demographics succeed and TIGER geometry fails, the app can still show city values without the boundary. If a live refresh fails while a cached profile is visible, the cached profile stays visible and is marked stale internally.
