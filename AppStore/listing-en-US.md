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

## Promotional Text (145 / 170)

```text
See your city’s population, income, housing, and education on one calm screen, straight from the U.S. Census Bureau. Now on iPad and Apple Watch.
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

On iPad and Apple Watch
• On iPad, your city fills the screen. In landscape, the details sit beside the summary.
• On Apple Watch, turn the Digital Crown through your city’s pages. LOC IQ finds your city on its own, even without your iPhone nearby.
• Add LOC IQ to your watch face to see your city’s outline and population at a glance.

Honest data
Every figure comes from the U.S. Census Bureau’s American Community Survey 5-year estimates for incorporated cities and census-designated places. When a value isn’t available, LOC IQ shows a dash instead of guessing. The source and data years are always one tap away.

Private by design
No account and no tracking. LOC IQ uses your location only while you’re using the app, sends a rounded coordinate to the Census Bureau to find your city, and keeps only your last city on your device.

Made for everyone
Text grows with your text size setting, up to the largest accessibility sizes. LOC IQ also supports VoiceOver, Increase Contrast, Reduce Motion, dark and light appearances, and keyboard shortcuts on iPad.

City data covers the 50 states, the District of Columbia, and Puerto Rico.

This product uses the Census Bureau Data API but is not endorsed or certified by the Census Bureau.
```

## What’s New (next version)

```text
• New Apple Watch app. It finds your city on its own, and a watch face complication shows your city at a glance.
• Redesigned for iPad: your city fills the screen, with the details beside it in landscape, plus keyboard shortcuts.
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

App Store Connect lets you declare supported accessibility features, and people can see them on the product page. Features are declared per device (iPhone, iPad, Apple Watch). Declare a feature for a device only after checking it on that device against Apple's evaluation criteria; the statuses below were checked on iPhone and iPad.

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

Keep the App Privacy answers consistent with `Shared/PrivacyInfo.xcprivacy`, which ships in the iPhone and iPad app and the watch app: **Precise Location**, used for **App Functionality**, **not linked** to identity, **not used for tracking**. No other data types are collected. The complication extension collects nothing and uses no required-reason APIs, so it carries no manifest of its own.

## Screenshots

The app runs on iPhone, iPad, and Apple Watch, so App Store Connect needs 6.9-inch iPhone screenshots (1320 × 2868), 13-inch iPad screenshots (2064 × 2752 portrait or 2752 × 2064 landscape), and Apple Watch screenshots (416 × 496 from a 46 mm Series 11, or 422 × 514 from a 49 mm Ultra).

- **Use live Census data.** Capture with a real city through a simulated location (`xcrun simctl location <device> set <lat>,<lon>` after granting location). The Debug fixture data is synthetic, so don't use it in store screenshots.
- **Suggested iPhone sequence:**
  1. Summary for a well-known city.
  2. Details: age, housing and commuting.
  3. Light appearance.
  4. The largest text size.
  5. The first-run screen: no account, location only while in use.
- **iPad:** lead with landscape, where the details sit beside the summary, then portrait.
- **Apple Watch:** the place page, then people, then homes and education. Debug builds accept `--lociq-watch-page <0-3>` to open a page directly.
