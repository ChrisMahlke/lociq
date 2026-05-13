# Lociq

Lociq is a minimal SwiftUI iPhone app that shows a city-level demographic snapshot for the user's current location.

## Current Scope

- Uses Core Location to resolve the current area.
- Uses U.S. Census ACS data for city-level demographics.
- Uses TIGERweb geometry for the city boundary outline.
- Does not use a map view or Google Maps SDK.
- Does not ship localized app strings.

## Configuration

Add local secrets in `Config/Secrets.xcconfig`:

```xcconfig
CENSUS_API_KEY = YOUR_CENSUS_API_KEY
```

`CENSUS_API_KEY` is also read from the process environment for local debugging.

## Testing

Run the baseline checks with:

```bash
./scripts/test_baseline.sh
```
