# App Store Listing (English, U.S.)

Copy for App Store Connect. Fields are checked against Apple's character limits. The name, subtitle and keywords are indexed for search, so no word is repeated between them. Promotional text can change at any time; the other fields change with a new version.

## Name (24 / 30)

```text
LOC IQ: City Census Data
```

## Subtitle (30 / 30)

```text
Demographics for where you are
```

## Keywords (98 / 100)

```text
population,income,housing,rent,home,value,commute,education,town,stats,acs,local,moving,relocation
```

Words already in the name or subtitle (city, census, data, demographics) are left out because Apple indexes them there. Every keyword describes something the app shows or a reason to use it; the app never shows ZIP-code, neighborhood or crime data, so those words are deliberately absent.

## Promotional Text (155 / 170)

```text
See your city’s population, income, housing, and education on one calm screen, straight from the U.S. Census Bureau. Now easier to read at every text size.
```

## Description

```text
LOC IQ shows the U.S. Census profile of the city you’re in. No searching, no maps, no clutter: open the app and your city is there.

At a glance
• Population and median age
• Median household income
• Households, and the share of owners and renters
• Adults with a bachelor’s degree or higher
• Population density, based on the city’s land area
• The city’s outline, with your location

One tap for more
• Age groups
• Median rent and median home value
• Vacant housing units
• Commuting: public transit, working from home, and average commute time

Honest data
Every figure comes from the U.S. Census Bureau’s American Community Survey 5-year estimates for incorporated cities and census-designated places. When a value isn’t available, LOC IQ shows a dash instead of guessing. The source and data years are always one tap away.

Private by design
No account and no tracking. LOC IQ uses your location only while you’re using the app, sends a rounded coordinate to the Census Bureau to find your city, and keeps only your last city on your device.

Made for everyone
Text grows with your text size setting, up to the largest accessibility sizes. LOC IQ also supports VoiceOver, Increase Contrast, Reduce Motion, and dark and light appearances.

City data covers the 50 states, the District of Columbia, and Puerto Rico.

This product uses the Census Bureau Data API but is not endorsed or certified by the Census Bureau.
```

## What’s New (next version)

```text
• If location is off, one tap now opens Settings. A saved city is clearly labeled when it may not be where you are.
• More accurate numbers: density now uses the city’s land area, and average commute time is corrected.
• City outlines follow the shoreline, show enclaves, and focus on the part of the city you’re in.
• Clearer messages when data can’t load, with Try Again only when it can help.
• Text grows with your text size setting, with better contrast and improved VoiceOver support.
• New Match System appearance, and the data source is shown in the details view.
• Faster: LOC IQ no longer downloads your city again every time you open it.
```

## Categories

- **Primary: Reference.** The app answers one factual question about a place. Reference is a smaller category than Utilities, so the app competes with fewer apps in its charts. `LSApplicationCategoryType` in `Config/AppInfo.plist` now says the same, but the App Store category itself is set only in App Store Connect.
- **Secondary: Travel.** People check a city's profile when they visit or consider moving.

## Age Rating

4+. The app has no user-generated content, web views or objectionable material.

## Accessibility Nutrition Labels

App Store Connect lets you declare supported accessibility features, and people can see them on the product page. Declare a feature only after checking it on a device against Apple's evaluation criteria.

| Feature | Status |
| --- | --- |
| Larger Text | Supported: text scales up to AX5 with no clipping or overlap (checked in the simulator). |
| Dark Interface | Supported: dark is the default. |
| Sufficient Contrast | Supported: every text style is at least 4.5:1 in both themes (computed). |
| Reduced Motion | Supported: no pulsing or rotation under Reduce Motion. |
| Differentiate Without Color Alone | Supported: bars are always labeled in text. |
| VoiceOver | Implemented; declare after a VoiceOver pass on a device. |
| Voice Control | Implemented (input labels); declare after a device pass. |
| Captions, Audio Descriptions | Not applicable: no audio or video. |

## App Privacy

Keep the App Privacy answers consistent with `Lociq/PrivacyInfo.xcprivacy`: **Precise Location**, used for **App Functionality**, **not linked** to identity, **not used for tracking**. No other data types are collected.

## Screenshots

The app runs on iPhone and iPad, so App Store Connect needs 6.9-inch iPhone screenshots (1320 × 2868) and 13-inch iPad screenshots.

- **Use live Census data.** Capture with a real city through a simulated location (`xcrun simctl location <device> set <lat>,<lon>` after granting location). The Debug fixture data is synthetic, so don't use it in store screenshots.
- **Suggested sequence:**
  1. Summary for a well-known city.
  2. Details: age, housing and commuting.
  3. Light appearance.
  4. The largest text size.
  5. The first-run screen: no account, location only while in use.
