# Lociq Privacy Policy and Support

Last updated: May 8, 2026

Lociq is an iOS app for exploring neighborhood context on a map. This page explains what data the app uses, where it comes from, how optional services work, and how to get support.

## Summary

- Lociq does not require an account.
- Lociq does not sell personal information.
- Lociq does not use app data for cross-app tracking.
- Location permission is optional and is requested only after you choose a location-related action, such as centering the map on your area.
- Neighborhood lookups use public data sources and map services to show boundary, demographic, housing, and place context.
- Saved places, recent lookups, notes, and pinned items are stored locally on your device.
- AI-assisted discovery is optional and only used when the app build is configured with a Gemini API key; otherwise discovery uses local ranking.

## No Account Required

Lociq does not include user accounts, login, registration, or a developer-operated user profile system. The app does not ask for your name, email address, phone number, or password.

Because there is no Lociq account system, the developer does not maintain an account database for users of the app.

## Location

Lociq can work without location permission. You can tap the map or search for places manually.

If you choose a location-related action, such as centering the map on your area, iOS may ask for permission to access your location while using the app. When granted, location is used to:

- Center the map near your current area.
- Help you explore nearby neighborhoods more quickly.
- Load neighborhood context for a selected area when you choose to interact with the map.

Lociq does not request background location access. Lociq does not continuously track your location in the background.

## Public Data Services

Lociq uses public and government data sources to provide neighborhood context, including:

- U.S. Census Bureau ACS 5-Year estimates.
- TIGERweb / TIGER boundary geometry.
- FCC Census Block API.

These services may receive lookup coordinates or related geographic query parameters so the app can resolve ZIP, Census tract, boundary, demographic, and housing information for the area you selected.

The app uses this data to render neighborhood profiles, map boundaries, comparison context, and discovery recommendations.

## Google Maps SDK

Lociq uses the Google Maps SDK for iOS to display the interactive map.

Google Maps SDK behavior is governed by Google's terms and privacy practices. Depending on Google's SDK behavior and configuration, Google may collect data such as:

- Device identifiers.
- Product interaction data.
- Crash data.
- Performance data.
- Other diagnostic or SDK operation data.

Lociq uses Google Maps to show the map, support map interaction, and render selected areas. Lociq does not use Google Maps SDK data for cross-app tracking.

## Optional Gemini Processing

Lociq includes optional AI-assisted discovery recommendations using the Gemini Developer API. This feature is only active when the app build is configured with a Gemini API key. If no Gemini API key is configured, Lociq uses local heuristic ranking instead.

When Gemini-assisted discovery is active, Lociq may send the following information to Gemini to generate recommendation text:

- The selected seed place.
- Nearby candidate places.
- Public demographic and housing metrics for those places.
- Recent place display titles from your local app history.

Gemini is used only to help rank and summarize neighborhood discovery recommendations. Lociq does not send account credentials because the app has no account system.

## Saved Local History

Lociq can store app history locally on your device, including:

- Recent lookups.
- Saved places.
- Pinned neighborhoods.
- Saved comparisons.
- Custom labels or notes you add.

This information is stored on your device using local app storage. It helps the app show your recent and saved neighborhood context without requiring an account.

Deleting the app from your device removes the app's local storage from that device according to normal iOS app deletion behavior.

## Data Sharing

Lociq uses third-party services only to provide app functionality, including map display, public data lookups, and optional AI-assisted discovery.

Lociq does not sell personal information. Lociq does not use collected data to track you across apps or websites owned by other companies.

## Children's Privacy

Lociq is a general neighborhood exploration tool and is not directed to children. The app does not knowingly collect personal information from children.

## Support

For app support or privacy questions, use the support contact or support URL provided with the App Store listing or the repository page that hosts this policy.

When requesting support, avoid sending sensitive personal information. If you are reporting a location or map issue, include only the general area needed to understand the problem.

## Changes to This Policy

This policy may be updated as Lociq changes. Updates will be published in the repository or public page that hosts this document.
