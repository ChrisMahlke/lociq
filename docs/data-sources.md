# Data Sources

Lociq uses U.S. Census services only.

## Census Geocoder

The Census geocoder resolves device coordinates into Census geography metadata. Lociq requests county, incorporated place, and census-designated place layers. The visible city label comes from the resolved place when available.

If the geocoder place label is incomplete but ACS returns a valid row name, the snapshot falls back to the ACS `NAME` field.

## ACS 5-Year API

Demographic values come from ACS 5-year place-level estimates. The UI intentionally displays city/place data only. It does not mix tract, block group, ZIP, or ZCTA values into city labels.

ACS responses are tabular JSON arrays, not object graphs. `ACSDemographicsVariableCatalog` owns the variable list, `ACSTableResponse` reads response rows, and `ACSDemographicsMapper` converts raw values into semantic domain models.

Suppressed, unavailable, and missing ACS values are normalized before reaching the UI. The visible unavailable marker is `--`.

## TIGERweb

TIGERweb provides GeoJSON place boundaries for incorporated places and census-designated places. The outline is visual context for the resolved place. It is not a map, and it does not change the geographic level of the demographics.

If TIGERweb fails but ACS succeeds, Lociq keeps the demographic profile visible without a boundary.

## Reliability

The Census HTTP layer applies short per-request timeouts and retry/backoff to transient failures. Network failures and no-data failures are classified separately so the app can show honest fallback states and preserve stale cache when possible.
