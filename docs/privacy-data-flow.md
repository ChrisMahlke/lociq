# Privacy And Data Flow

Lociq uses the device location only to request a city-level Census profile.

## What Leaves The Device

When location access is granted, the app sends latitude and longitude to the Census geocoder only. The geocoder returns Census place identifiers that are then used for ACS and TIGERweb requests:

- Census geocoder receives latitude and longitude to resolve the place.
- ACS API receives Census geography identifiers, such as state and place codes, to request place-level demographics.
- TIGERweb receives Census geography identifiers, such as state and place codes, to request place boundary geometry.

The app does not send the coordinate to an app-owned server.

## What Stays On The Device

The app stores the last successful city profile in `UserDefaults` so launches and failed refreshes can keep showing useful data. The cached payload includes:

- UI-ready demographic snapshot
- optional city boundary GeoJSON
- coordinate used for the profile
- horizontal accuracy when available
- cache timestamp
- typed partial-failure metadata when a subrequest failed

## Permission Behavior

The app does not show a search box. If location access is unavailable, the UI stays minimal and asks the user to enable location access through the bottom action.

## Data Retention

Cached data is local to the app installation. The freshness policy currently treats cached profiles older than one day as stale. Stale data can remain visible if live Census services cannot refresh.
