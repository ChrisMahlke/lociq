# Privacy And Data Flow

Lociq uses the device location only to request a city-level Census profile.

## What Leaves The Device

When location access is granted, the app sends a coordinate rounded to 4 decimal places (about 11 m) to the Census geocoder only. The geocoder returns Census place identifiers that are then used for ACS and TIGERweb requests:

- Census geocoder receives the rounded latitude and longitude to resolve the place.
- ACS API receives Census geography identifiers, such as state and place codes, to request place-level demographics.
- TIGERweb receives Census geography identifiers, such as state and place codes, to request place boundary geometry.

The app does not send the coordinate to an app-owned server, and does not share it: the share sheet text contains only the city and its statistics.

## What Stays On The Device

The app stores the last successful city profile in a file in Application Support (`ProfileCache/last-city-profile.json`), written atomically and excluded from iCloud and computer backups. The cached payload includes:

- UI-ready demographic snapshot
- optional city boundary GeoJSON
- the lookup coordinate and the latest marker coordinate, rounded to 4 decimal places
- horizontal accuracy when available, and whether location was approximate
- cache timestamp, data vintage, and place identifier
- typed partial-failure metadata when a subrequest failed

Earlier builds kept this profile in `UserDefaults` under `lociq.lastCityProfile.v1`. The first launch of a newer build moves it to the file and removes the key, so no coordinates remain in the defaults plist. `UserDefaults` now holds only the appearance choice and whether the details hint was dismissed.

Diagnostics logs record failure categories and durations, never coordinates.

## Permission Behavior

The app does not show a search box and never asks for location at launch. On first run it explains what it shows and asks when the user taps the location button.

- If access is denied or Location Services are off, the app says so and offers one button that opens LOC IQ's page in Settings. Returning with access enabled loads the city without a relaunch.
- If access is restricted, the app says so and offers no action.
- If a saved city is shown without current access (for example after "Allow Once" expired), it is labeled "LAST LOCATION" or "SAVED CITY · LOCATION OFF", and refresh asks for access first.
- With "Precise Location" off, the profile is labeled "APPROXIMATE AREA" and the marker shows the size of the uncertainty instead of a precise dot.

## Data Retention

Cached data is local to the app installation and is removed when the app is deleted. A cached profile stays in use while the user remains in its place and the app requests the same Census release; there is no clock-based expiry, because ACS estimates change once a year.

Builds before the city-profile redesign stored a list of saved places under `io.chrismahlke.lociq.neighborhoodLibrary`. Current builds neither read nor remove it. Whether to migrate or delete it depends on whether such a build reached App Store users; see the 2026-09-27 review, item E1.
