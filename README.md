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
- U.S. Census Bureau APIs
- Gemini Developer API for optional AI-assisted discovery recommendations

## Project Structure

- [`Lociq`](/Users/chrismahlke/ios/lociq/Lociq): App source
- [`Config`](/Users/chrismahlke/ios/lociq/Config): Build configuration and local setup files
- [`LociqTests`](/Users/chrismahlke/ios/lociq/LociqTests): Unit tests
- [`LociqUITests`](/Users/chrismahlke/ios/lociq/LociqUITests): UI tests

## Requirements

- Xcode 16 or newer
- iOS 16.0 or newer
- A Google Maps SDK for iOS API key
- Optional Gemini API key for AI-assisted discovery mode

## Getting Started

1. Open [`Lociq.xcodeproj`](/Users/chrismahlke/ios/lociq/Lociq.xcodeproj) in Xcode.
2. Sync your Google Maps SDK for iOS key from Secret Manager into `Config/GoogleMaps.xcconfig`.
3. Select an iPhone or simulator target in Xcode.
4. Build and run.

Example sync command:

```bash
./scripts/sync_google_maps_key.sh --project YOUR_GCP_PROJECT_ID
```

The sync script validates that the secret resolves to a Google Maps API key with:

- `iOS apps` application restriction
- allowed bundle ID `io.chrismahlke.lociq`
- `Maps SDK for iOS` API access

Manual fallback:

1. Copy [`Config/GoogleMaps.example.xcconfig`](/Users/chrismahlke/ios/lociq/Config/GoogleMaps.example.xcconfig) to `Config/GoogleMaps.xcconfig`.
2. Add your real Google Maps SDK for iOS key to `Config/GoogleMaps.xcconfig`.

Example local config:

```xcconfig
// Local-only Google Maps SDK for iOS key. Do not commit this file.
GOOGLE_MAPS_API_KEY = YOUR_GOOGLE_MAPS_API_KEY
GEMINI_API_KEY = YOUR_GEMINI_API_KEY
GEMINI_MODEL = gemini-2.5-flash
```

## Local Configuration

The project uses local configuration files so the real Google Maps key is not hardcoded in Swift source and should not be committed.

- Committed example: [`Config/GoogleMaps.example.xcconfig`](/Users/chrismahlke/ios/lociq/Config/GoogleMaps.example.xcconfig)
- Local file for your real key: `Config/GoogleMaps.xcconfig`
- Optional local secrets file: `Config/Secrets.xcconfig`
- Secret Manager sync helper: [`scripts/sync_google_maps_key.sh`](/Users/chrismahlke/ios/lociq/scripts/sync_google_maps_key.sh)

The app reads configuration through [`AppConfig.swift`](/Users/chrismahlke/ios/lociq/Lociq/AppConfig.swift), and Google Maps is initialized at startup in [`LociqApp.swift`](/Users/chrismahlke/ios/lociq/Lociq/LociqApp.swift).

Only the resolved runtime values are written into the built app's `Info.plist`; the local `.xcconfig` files themselves are not copied into the app bundle.

If `GEMINI_API_KEY` is blank, Lociq falls back to local heuristic discovery picks and still works without AI.

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

Recommended local workflow:

1. Store the client key in Secret Manager as `lociq-google-maps-api-key`.
2. Keep the key restricted in Google Cloud to the iOS bundle ID above and only the Maps APIs your app uses.
3. Sync the latest value locally with `./scripts/sync_google_maps_key.sh --project YOUR_GCP_PROJECT_ID`.
4. Build the app normally in Xcode.

This app should not fetch Secret Manager at runtime. For Maps SDK for iOS, the secure pattern is a tightly restricted client key injected at build time.

## Data Sources

- U.S. Census Bureau ACS 5-Year estimates
- TIGERweb / TIGER boundary geometry
- FCC Census Block API

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
- Do not commit `Config/Secrets.xcconfig`.
- Treat the key as deployable client configuration, not as a server secret.
- Real protection comes from Google Cloud restrictions on bundle ID and API scope.
- Secret Manager is used as the storage and rotation source, not as a runtime dependency for the shipped iOS app.

## License

No license file is currently included in this repository.
