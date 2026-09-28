# Data Sources

Lociq uses U.S. Census services only. One constant, `CensusDataVintage.current`, sets the release every request and label uses, so place codes, statistics, boundaries, and the displayed source always describe the same geography.

## Census Geocoder

The Census geocoder resolves device coordinates into Census geography metadata. Lociq requests county, incorporated place, and census-designated place layers with the `ACS{year}_Current` vintage, so every place it returns also has ACS statistics and a generalized boundary for that year. Coordinates are sent with 4 decimal places (about 11 m).

The title uses the Census base name ("Juneau", not "Juneau city and borough") plus the state abbreviation. The eight consolidated "(balance)" places, whose base name is the full legal name, use a small table keyed by GEOID ("Nashville", "Louisville", "Indianapolis", …).

## ACS 5-Year API

Demographic values come from ACS 5-year place-level estimates (2020–2024 for the 2024 release). The UI displays city/place data only. It does not mix tract, block group, ZIP, or ZCTA values into city labels.

ACS responses are tabular JSON arrays, not object graphs. `ACSDemographicsVariableCatalog` owns the variable list, `ACSTableResponse` reads response rows, and `ACSDemographicsMapper` converts raw values into semantic domain models.

- Suppressed, unavailable, and missing values, including JSON `null` cells, are normalized to the visible marker `--`.
- Medians in an open-ended interval are shown with their Census annotation, such as `$250,000+`, read from the `EA` annotation variables.
- Average commute divides aggregate travel time (B08013) by workers who did not work from home (B08301 total minus B08301_021), which is that table's universe.
- Households fall back to all units minus vacant units when tenure is unavailable, never to all units.

## TIGERweb

Boundaries come from the generalized service `Generalized_ACS{year}/Places_CouSub_ConCity_SubMCD`: layer 10 for incorporated places and layer 11 for CDPs. These outlines are clipped to the shoreline, match the ACS year, and are several times smaller than legal boundaries.

- Density is population divided by the boundary's `AREALAND` (Census land area), rounded to two significant figures. Without land area, no density is shown.
- Holes (enclaves belonging to other places) are kept and drawn with the even-odd rule.
- The glyph fits the part that contains the user, or the largest part; distant islands are not drawn.

The outline is visual context for the resolved place. It is not a map, and it does not change the geographic level of the demographics. If TIGERweb fails but ACS succeeds, Lociq keeps the demographic profile visible without a boundary.

## Reliability

The Census HTTP layer applies per-request timeouts and retry/backoff to transient failures: 3 attempts for the geocoder and ACS, 2 for boundaries. A whole load is bounded at 25 seconds. Cancellation is never retried. Network, service, and no-data failures are classified separately so the app can show honest fallback states.

## Attribution

The details view shows the source ("U.S. CENSUS BUREAU", "ACS 5-YEAR · 2020–2024") and the notice the Census Data API Terms of Service ask apps to display: "This product uses the Census Bureau Data API but is not endorsed or certified by the Census Bureau."

## Annual Vintage Update

Each year, after the Census Bureau publishes the next ACS 5-year release and its generalized boundaries:

1. Confirm the geocoder lists the new vintage: <https://geocoding.geo.census.gov/geocoder/vintages?benchmark=Public_AR_Current&format=json>.
2. Confirm the generalized boundary service exists and check its layer ids and field types (`AREALAND` has been a string in some years and a number in others; decoding accepts both): `https://tigerweb.geo.census.gov/arcgis/rest/services/Generalized_ACS{year}/Places_CouSub_ConCity_SubMCD/MapServer?f=json`.
3. Confirm every variable in `ACSDemographicsVariableCatalog` exists for the new year.
4. Bump `CensusDataVintage.current`, and update layer ids if they changed.
5. Run the tests. Cached profiles from the previous vintage reload automatically at the next location fix.
