# Lociq Privacy Policy and Support

Last updated: September 28, 2026

Lociq is a minimal app for iPhone, iPad, and Apple Watch that shows a city-level demographic snapshot for your current area.

## Summary

- Lociq does not require an account.
- Lociq does not sell personal information.
- Lociq does not use app data for cross-app tracking.
- Location permission is optional and used only to load a local city profile.
- Demographic values and boundary geometry come from public U.S. Census services.
- The latest loaded city profile may be cached locally on your device, excluded from backups.

## Location

If location access is granted, Lociq requests your current location (precise location, with about 100-meter accuracy, unless you turn off Precise Location) to resolve the city, load ACS demographic estimates, and draw the city boundary. The coordinate sent to the U.S. Census Geocoder is rounded to about 11 meters. Lociq does not request background location access and does not continuously track your location in the background.

If location access is not granted, the app shows a minimal location-disabled state with a button that opens Lociq's page in Settings.

The Apple Watch app asks for location separately, on the watch, and uses it the same way. If you don't allow it, the watch app explains where to turn it on.

## Public Data Services

Lociq uses public government data sources:

- U.S. Census Bureau ACS 5-Year estimates.
- U.S. Census Geocoder.
- TIGERweb / TIGER boundary geometry.

The Census Geocoder receives the rounded lookup coordinate. The ACS and TIGERweb services receive only Census geographic identifiers. This product uses the Census Bureau Data API but is not endorsed or certified by the Census Bureau.

## Local Storage

Lociq may store the latest loaded city profile, including a rounded coordinate, in a file on your device so the app can reopen gracefully. The file is excluded from iCloud and computer backups. Deleting the app removes this local storage according to normal iOS and watchOS app deletion behavior.

On Apple Watch, Lociq's watch face complications read a small separate record: the city's name, population, and outline, and when Lociq last showed it as your city. It contains no location coordinates. The complications never access your location or the network.

## Support

For app support or privacy questions, use the support contact or support URL provided with the App Store listing or repository page.
