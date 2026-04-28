# Lociq

Lociq is a SwiftUI iOS app for exploring neighborhood context on an interactive map. Tap a location to load ZIP-level and Census tract-level demographic data, compare boundary scales, and review a compact neighborhood profile in a bottom sheet.

## Highlights

- Interactive Google Maps experience with tap-to-explore behavior
- ZIP and Census tract boundary overlays
- Census-driven demographic and housing context
- Bottom sheet insights UI with map-first navigation
- First-run onboarding flow

## Tech Stack

- Swift
- SwiftUI
- Google Maps SDK for iOS
- Optional Firebase callable backend for shared Census logic
- U.S. Census Bureau APIs

## Project Structure

- [`Lociq`](/Users/chrismahlke/ios/lociq/Lociq): App source
- [`Config`](/Users/chrismahlke/ios/lociq/Config): Build configuration and local setup files
- [`LociqTests`](/Users/chrismahlke/ios/lociq/LociqTests): Unit tests
- [`LociqUITests`](/Users/chrismahlke/ios/lociq/LociqUITests): UI tests

## Requirements

- Xcode 16 or newer
- iOS 16.0 or newer
- A Google Maps SDK for iOS API key

## Getting Started

1. Open [`Lociq.xcodeproj`](/Users/chrismahlke/ios/lociq/Lociq.xcodeproj) in Xcode.
2. Copy [`Config/GoogleMaps.example.xcconfig`](/Users/chrismahlke/ios/lociq/Config/GoogleMaps.example.xcconfig) to `Config/GoogleMaps.xcconfig`.
3. Add your real Google Maps SDK for iOS key to `Config/GoogleMaps.xcconfig`.
4. Select an iPhone or simulator target in Xcode.
5. Build and run.

Example local config:

```xcconfig
// Local-only Google Maps SDK for iOS key. Do not commit this file.
GOOGLE_MAPS_API_KEY = YOUR_GOOGLE_MAPS_API_KEY
```

## Local Configuration

The project uses local configuration files so the real Google Maps key is not hardcoded in Swift source and should not be committed.

- Committed example: [`Config/GoogleMaps.example.xcconfig`](/Users/chrismahlke/ios/lociq/Config/GoogleMaps.example.xcconfig)
- Local file for your real key: `Config/GoogleMaps.xcconfig`
- Optional local secrets file: `Config/Secrets.xcconfig`
- Optional Firebase bundle file: `Config/GoogleService-Info.plist`

The app reads configuration through [`AppConfig.swift`](/Users/chrismahlke/ios/lociq/Lociq/AppConfig.swift), and Google Maps is initialized at startup in [`LociqApp.swift`](/Users/chrismahlke/ios/lociq/Lociq/LociqApp.swift).

To enable the shared Firebase backend, add these keys to `Config/Secrets.xcconfig`:

```xcconfig
USE_FIREBASE_LOCIQ_BACKEND = true
FIREBASE_FUNCTIONS_REGION = us-central1
```

When that flag is on, `CensusZipDemographicsService` will attempt the shared Firebase callable path first and fall back to the direct Census/FCC/TIGERweb path if Firebase is unavailable or the call fails.

The Firebase callable path also requires:

- `Config/GoogleService-Info.plist` from Firebase for bundle id `io.chrismahlke.lociq`
- Firebase App Check to be registered for the iOS app
- Firebase Authentication Anonymous sign-in to be enabled for the project
- Lociq uses `DeviceCheckProvider` on physical devices and `AppCheckDebugProvider` on the simulator

Only the resolved runtime values are written into the built app's `Info.plist`; the local `.xcconfig` files themselves are not copied into the app bundle.

## Google Maps Setup

In Google Cloud:

1. Create or select a project.
2. Enable `Maps SDK for iOS`.
3. Create an API key.
4. Restrict the key by iOS app bundle identifier.
5. Restrict API usage to `Maps SDK for iOS`.

Current bundle identifier:

```text
io.chrismahlke.lociq
```

## Data Sources

- U.S. Census Bureau ACS 5-Year estimates
- TIGERweb / TIGER boundary geometry
- FCC Census Block API
- Firebase callable wrappers for shared Census lookup logic

## Firebase Migration Notes

- `fetchZipBundle`, `fetchNeighborhoodBoundaries`, and `fetchDemographics` now have an optional Firebase client path.
- The direct REST implementation is still present as a fallback so the app remains usable during migration.
- Apple geocoding should stay local for now. It is UI-native and separate from the shared Census backend logic.

## Development Notes

- Google Maps initialization is performed at app startup.
- If the Google Maps key is missing, the app logs a clear message and falls back to a missing-key state instead of silently failing.

## Testing

Run tests from Xcode or with:

```bash
xcodebuild test -project Lociq.xcodeproj -scheme Lociq -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Security Notes

- Do not commit `Config/GoogleMaps.xcconfig`.
- Do not commit `Config/Secrets.xcconfig` or `Config/GoogleService-Info.plist`.
- Treat the key as deployable client configuration, not as a server secret.
- Real protection comes from Google Cloud restrictions on bundle ID and API scope.

## License

No license file is currently included in this repository.
