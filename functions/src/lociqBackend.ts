import * as logger from "firebase-functions/logger";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { makeNeighborhoodInsights, type InsightResponse } from "./lociqInsights.js";

type GeoJSONPosition = [number, number];
type GeoJSONPolygonCoordinates = GeoJSONPosition[][];
type GeoJSONMultiPolygonCoordinates = GeoJSONPosition[][][];

type GeoJSONGeometry =
  | { type: "Polygon"; coordinates: GeoJSONPolygonCoordinates }
  | { type: "MultiPolygon"; coordinates: GeoJSONMultiPolygonCoordinates }
  | { type: string; coordinates?: unknown };

type GeoJSONFeature = {
  type: "Feature";
  properties?: Record<string, string | null>;
  geometry?: GeoJSONGeometry | null;
};

type GeoJSONFeatureCollection = {
  type: "FeatureCollection";
  features: GeoJSONFeature[];
};

type CountyInfo = {
  name: string;
  stateFIPS?: string | null;
  countyFIPS?: string | null;
  geoid?: string | null;
};

type TractInfo = {
  name?: string | null;
  geoid?: string | null;
  stateFIPS?: string | null;
  countyFIPS?: string | null;
  tractCode?: string | null;
};

type PlaceInfo = {
  name: string;
  stateFIPS?: string | null;
  placeFIPS?: string | null;
  type: "incorporatedPlace" | "censusDesignatedPlace" | "unknown";
};

type Demographics = {
  name: string;
  population?: number | null;
  medianHouseholdIncome?: number | null;
  medianAge?: number | null;
  housingUnits?: number | null;
  medianHomeValue?: number | null;
  medianGrossRent?: number | null;
  averageHouseholdSize?: number | null;
  ownerOccupied?: number | null;
  renterOccupied?: number | null;
  ownerOccupiedPct?: number | null;
  renterOccupiedPct?: number | null;
  workersTotal?: number | null;
  workersWfh?: number | null;
  workersWfhPct?: number | null;
  povertyUniverse?: number | null;
  povertyBelow?: number | null;
  povertyRatePct?: number | null;
  whiteAlone?: number | null;
  blackAlone?: number | null;
  asianAlone?: number | null;
  hispanicOrLatino?: number | null;
};

type ZipBundleResponse = {
  zcta: string;
  county: CountyInfo | null;
  tract: TractInfo | null;
  place: PlaceInfo | null;
  isIncorporatedPlace: boolean;
  boundary: GeoJSONFeatureCollection;
  boundaryMetrics: null;
  demographics: Demographics;
  insights: InsightResponse[];
};

type NeighborhoodBoundariesResponse = {
  zip: GeoJSONFeatureCollection;
  tract: GeoJSONFeatureCollection | null;
  block: GeoJSONFeatureCollection | null;
};

type ScaleDemographicsResponse = {
  zip: Demographics;
  tract: Demographics | null;
};

type PlaceProfileResponse = {
  zipBundle: ZipBundleResponse;
  boundaries: NeighborhoodBoundariesResponse;
  scaleDemographics: ScaleDemographicsResponse;
};

type ComparisonProfileResponse = {
  id: string;
  title: string;
  subtitle: string;
  demographics: Demographics;
  metricsSource: "zcta" | "tract";
};

type CallableRequest = {
  latitude?: unknown;
  longitude?: unknown;
  scale?: unknown;
  zcta?: unknown;
  tractGeoid?: unknown;
  fallbackTitle?: unknown;
  fallbackSubtitle?: unknown;
  locale?: unknown;
};

type GeographiesBundle = {
  zcta: string;
  county: CountyInfo | null;
  tract: TractInfo | null;
  place: PlaceInfo | null;
};

type CensusGeocoderResponse = {
  result?: {
    geographies?: Record<string, CensusGeocoderGeography[]>;
  };
};

type CensusGeocoderGeography = {
  ZCTA5?: string;
  NAME?: string;
  BASENAME?: string;
  GEOID?: string;
  STATE?: string;
  COUNTY?: string;
  TRACT?: string;
  PLACE?: string;
};

type FCCBlockResponse = {
  Block?: {
    fips?: string;
  };
};

const REGION = process.env.FIREBASE_FUNCTIONS_REGION || process.env.FUNCTIONS_REGION || "us-central1";
const ACS_YEAR = Number(process.env.LOCIQ_ACS_YEAR || "2024");
const CENSUS_API_KEY = (process.env.CENSUS_API_KEY || "").trim();
const GEOCODER_BENCHMARK = "Public_AR_Current";
const GEOCODER_VINTAGE = "Current_Current";
const ZCTA_LAYER_ID = "2";
const TRACT_LAYER_ID = "8";
const COUNTY_LAYER_ID = "82";
const INCORPORATED_PLACES_LAYER_ID = "28";
const CDP_LAYER_ID = "30";
const BLOCK_LAYER_ID = "12";
const GEOCODER_COORDINATES_URL =
  "https://geocoding.geo.census.gov/geocoder/geographies/coordinates";
const TIGERWEB_MAPSERVER_BASE_URL =
  "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Current/MapServer";
const FCC_CENSUS_URL = "https://geo.fcc.gov/api/census/block/find";
const ZIP_REGEX = /^[0-9]{5}$/;
const TRACT_REGEX = /^[0-9]{11}$/;
const BLOCK_REGEX = /^[0-9]{15}$/;

class TTLCache<T> {
  private readonly values = new Map<string, { expiresAt: number; value: T }>();
  private readonly inflight = new Map<string, Promise<T>>();

  async getOrSet(key: string, ttlMs: number, loader: () => Promise<T>): Promise<T> {
    const now = Date.now();
    const existing = this.values.get(key);
    if (existing && existing.expiresAt > now) {
      return existing.value;
    }

    const pending = this.inflight.get(key);
    if (pending) {
      return pending;
    }

    const created = loader()
      .then((value) => {
        this.values.set(key, {
          expiresAt: Date.now() + ttlMs,
          value,
        });
        this.inflight.delete(key);
        this.evictExpired();
        return value;
      })
      .catch((error) => {
        this.inflight.delete(key);
        throw error;
      });

    this.inflight.set(key, created);
    return created;
  }

  private evictExpired() {
    const now = Date.now();
    for (const [key, entry] of this.values.entries()) {
      if (entry.expiresAt <= now) {
        this.values.delete(key);
      }
    }
  }
}

const externalApiCache = new TTLCache<unknown>();
const derivedResponseCache = new TTLCache<unknown>();

const acsExtendedVariables = [
  "NAME",
  "B01003_001E",
  "B19013_001E",
  "B01002_001E",
  "B25001_001E",
  "B25077_001E",
  "B25064_001E",
  "B25010_001E",
  "B25003_002E",
  "B25003_003E",
  "B08301_001E",
  "B08301_021E",
  "B17001_001E",
  "B17001_002E",
  "B02001_002E",
  "B02001_003E",
  "B02001_005E",
  "B03003_003E",
];

export function onCallLociq<T>(
  handler: (request: NormalizedCallableRequest) => Promise<T>
) {
  return onCall(
    {
      region: REGION,
      enforceAppCheck: true,
      consumeAppCheckToken: false,
    },
    async (request) => {
      const normalized = normalizeCallableRequest(request.data as CallableRequest);
      return handler(normalized);
    }
  );
}

export async function buildZipBundle(
  latitude: number,
  longitude: number,
  locale: string | null = null
): Promise<ZipBundleResponse> {
  const cacheKey = `zipBundle:${coordinateKey(latitude, longitude)}:${locale ?? "default"}`;
  return withDerivedCache(cacheKey, 5 * 60_000, async () => {
    const geo = await fetchGeographiesFromCoordinate(latitude, longitude);
    const [boundary, demographics] = await Promise.all([
      fetchZctaBoundaryGeoJson(geo.zcta),
      fetchAcsDemographicsForZip(geo.zcta),
    ]);

    return {
      zcta: geo.zcta,
      county: geo.county,
      tract: geo.tract,
      place: geo.place,
      isIncorporatedPlace: geo.place?.type === "incorporatedPlace",
      boundary,
      boundaryMetrics: null,
      demographics,
      insights: makeNeighborhoodInsights(demographics, locale),
    };
  });
}

export async function buildNeighborhoodBoundaries(
  latitude: number,
  longitude: number,
  tractGeoid: string | null,
  zcta: string | null
): Promise<NeighborhoodBoundariesResponse> {
  const cacheKey = `boundaries:${coordinateKey(latitude, longitude)}:${tractGeoid ?? "none"}:${zcta ?? "none"}`;
  return withDerivedCache(cacheKey, 5 * 60_000, async () => {
    const zip = zcta && ZIP_REGEX.test(zcta) ? await fetchZctaBoundaryGeoJson(zcta) : await buildZipBundle(latitude, longitude).then((bundle) => bundle.boundary);
    const blockFips = await fetchBlockFips(latitude, longitude).catch(() => null);
    const tractFromBlock =
      blockFips && blockFips.length >= 11 ? blockFips.slice(0, 11) : null;
    const tractToUse = tractFromBlock ?? tractGeoid;

    const [tract, block] = await Promise.all([
      fetchTractBoundary(tractToUse),
      fetchBlockBoundary(blockFips),
    ]);

    return { zip, tract, block };
  });
}

export async function buildDemographicsForScale(
  latitude: number,
  longitude: number,
  scale: "zip" | "tract",
  zcta: string | null,
  tractGeoid: string | null
): Promise<{ demographics: Demographics; resolvedScale: "zip" | "tract" }> {
  if (scale === "zip") {
    const resolvedZcta = zcta ?? (await fetchGeographiesFromCoordinate(latitude, longitude)).zcta;
    return {
      demographics: await fetchAcsDemographicsForZip(resolvedZcta),
      resolvedScale: "zip",
    };
  }

  const blockFips = await fetchBlockFips(latitude, longitude).catch(() => null);
  const tractFromBlock =
    blockFips && blockFips.length >= 11 ? blockFips.slice(0, 11) : null;
  const tractToUse = tractFromBlock ?? tractGeoid;

  if (!tractToUse || !TRACT_REGEX.test(tractToUse)) {
    throw new HttpsError("not-found", "No tract demographics found for this coordinate.");
  }

  return {
    demographics: await fetchAcsDemographicsForTract(tractToUse),
    resolvedScale: "tract",
  };
}

export async function buildPlaceProfile(
  latitude: number,
  longitude: number,
  locale: string | null = null
): Promise<PlaceProfileResponse> {
  const cacheKey = `placeProfile:${coordinateKey(latitude, longitude)}:${locale ?? "default"}`;
  return withDerivedCache(cacheKey, 5 * 60_000, async () => {
    const zipBundle = await buildZipBundle(latitude, longitude, locale);
    const [boundaries, tractDemographics] = await Promise.all([
      buildNeighborhoodBoundaries(
        latitude,
        longitude,
        zipBundle.tract?.geoid ?? null,
        zipBundle.zcta
      ),
      zipBundle.tract?.geoid
        ? fetchAcsDemographicsForTract(zipBundle.tract.geoid).catch(() => null)
        : Promise.resolve(null),
    ]);

    return {
      zipBundle,
      boundaries,
      scaleDemographics: {
        zip: zipBundle.demographics,
        tract: tractDemographics,
      },
    };
  });
}

export async function buildComparisonProfile(
  latitude: number,
  longitude: number,
  scale: "zip" | "tract",
  fallbackTitle: string,
  fallbackSubtitle: string
): Promise<ComparisonProfileResponse> {
  const cacheKey = `comparison:${coordinateKey(latitude, longitude)}:${scale}`;
  return withDerivedCache(cacheKey, 5 * 60_000, async () => {
    const profile = await buildPlaceProfile(latitude, longitude);
    const demographics =
      scale === "tract" && profile.scaleDemographics.tract
        ? profile.scaleDemographics.tract
        : profile.scaleDemographics.zip;

    return {
      id: profile.zipBundle.tract?.geoid || profile.zipBundle.zcta,
      title: makeComparisonTitle(profile.zipBundle, fallbackTitle),
      subtitle: makeComparisonSubtitle(profile.zipBundle, fallbackSubtitle),
      demographics,
      metricsSource:
        scale === "tract" && profile.scaleDemographics.tract ? "tract" : "zcta",
    };
  });
}

function normalizeCallableRequest(data: CallableRequest): NormalizedCallableRequest {
  return {
    latitude: parseCoordinate(data.latitude, "latitude"),
    longitude: parseCoordinate(data.longitude, "longitude"),
    scale: parseScale(data.scale),
    zcta: parseOptionalString(data.zcta),
    tractGeoid: parseOptionalString(data.tractGeoid),
    fallbackTitle: parseOptionalString(data.fallbackTitle),
    fallbackSubtitle: parseOptionalString(data.fallbackSubtitle),
    locale: parseOptionalString(data.locale),
  };
}

type NormalizedCallableRequest = {
  latitude: number;
  longitude: number;
  scale: "zip" | "tract";
  zcta: string | null;
  tractGeoid: string | null;
  fallbackTitle: string | null;
  fallbackSubtitle: string | null;
  locale: string | null;
};

function parseCoordinate(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `Missing or invalid ${label}.`);
  }

  return value;
}

function parseScale(value: unknown): "zip" | "tract" {
  return value === "tract" ? "tract" : "zip";
}

function parseOptionalString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

async function fetchGeographiesFromCoordinate(
  latitude: number,
  longitude: number
): Promise<GeographiesBundle> {
  const url = new URL(GEOCODER_COORDINATES_URL);
  url.searchParams.set("x", String(longitude));
  url.searchParams.set("y", String(latitude));
  url.searchParams.set("benchmark", GEOCODER_BENCHMARK);
  url.searchParams.set("vintage", GEOCODER_VINTAGE);
  url.searchParams.set(
    "layers",
    [
      ZCTA_LAYER_ID,
      COUNTY_LAYER_ID,
      TRACT_LAYER_ID,
      INCORPORATED_PLACES_LAYER_ID,
      CDP_LAYER_ID,
    ].join(",")
  );
  url.searchParams.set("format", "json");

  const decoded = await fetchJson<CensusGeocoderResponse>(url.toString());
  return {
    zcta: extractZcta(decoded),
    county: extractCountyInfo(decoded),
    tract: extractTractInfo(decoded),
    place: extractPlaceInfo(decoded),
  };
}

function extractZcta(decoded: CensusGeocoderResponse): string {
  const zctaKey = "2020 Census ZIP Code Tabulation Areas";
  const keyedMatch = decoded.result?.geographies?.[zctaKey]?.[0]?.ZCTA5;
  if (keyedMatch && ZIP_REGEX.test(keyedMatch)) {
    return keyedMatch;
  }

  for (const entryList of Object.values(decoded.result?.geographies ?? {})) {
    const candidate = entryList[0]?.ZCTA5;
    if (candidate && ZIP_REGEX.test(candidate)) {
      return candidate;
    }
  }

  throw new HttpsError("not-found", "No ZIP-backed neighborhood profile found.");
}

function extractCountyInfo(decoded: CensusGeocoderResponse): CountyInfo | null {
  const geographies = decoded.result?.geographies ?? {};
  const county = geographies["Counties"]?.[0];
  if (county) {
    return {
      name: county.NAME ?? county.BASENAME ?? "County",
      stateFIPS: county.STATE ?? null,
      countyFIPS: county.COUNTY ?? null,
      geoid: county.GEOID ?? null,
    };
  }

  for (const entryList of Object.values(geographies)) {
    const first = entryList[0];
    if (first?.COUNTY) {
      return {
        name: first.NAME ?? first.BASENAME ?? "County",
        stateFIPS: first.STATE ?? null,
        countyFIPS: first.COUNTY ?? null,
        geoid: first.GEOID ?? null,
      };
    }
  }

  return null;
}

function extractTractInfo(decoded: CensusGeocoderResponse): TractInfo | null {
  const geographies = decoded.result?.geographies ?? {};
  const tract = geographies["Census Tracts"]?.[0];
  if (tract) {
    const geoid = tract.GEOID ?? null;
    return {
      name: tract.NAME ?? tract.BASENAME ?? null,
      geoid,
      stateFIPS: tract.STATE ?? null,
      countyFIPS: tract.COUNTY ?? null,
      tractCode: tract.TRACT ?? (geoid ? geoid.slice(-6) : null),
    };
  }

  for (const entryList of Object.values(geographies)) {
    const first = entryList[0];
    if (first?.TRACT) {
      return {
        name: first.NAME ?? first.BASENAME ?? null,
        geoid: first.GEOID ?? null,
        stateFIPS: first.STATE ?? null,
        countyFIPS: first.COUNTY ?? null,
        tractCode: first.TRACT,
      };
    }

    if (first?.GEOID && TRACT_REGEX.test(first.GEOID)) {
      return {
        name: first.NAME ?? first.BASENAME ?? null,
        geoid: first.GEOID,
        stateFIPS: first.STATE ?? null,
        countyFIPS: first.COUNTY ?? null,
        tractCode: first.GEOID.slice(-6),
      };
    }
  }

  return null;
}

function extractPlaceInfo(decoded: CensusGeocoderResponse): PlaceInfo | null {
  const geographies = decoded.result?.geographies ?? {};

  const incorporated = geographies["Incorporated Places"]?.[0];
  if (incorporated) {
    const name = incorporated.NAME ?? incorporated.BASENAME;
    if (name) {
      return {
        name,
        stateFIPS: incorporated.STATE ?? null,
        placeFIPS: incorporated.PLACE ?? null,
        type: "incorporatedPlace",
      };
    }
  }

  const cdp = geographies["Census Designated Places"]?.[0];
  if (cdp) {
    const name = cdp.NAME ?? cdp.BASENAME;
    if (name) {
      return {
        name,
        stateFIPS: cdp.STATE ?? null,
        placeFIPS: cdp.PLACE ?? null,
        type: "censusDesignatedPlace",
      };
    }
  }

  for (const entryList of Object.values(geographies)) {
    const first = entryList[0];
    const name = first?.NAME ?? first?.BASENAME;
    if (name && first?.PLACE) {
      return {
        name,
        stateFIPS: first.STATE ?? null,
        placeFIPS: first.PLACE ?? null,
        type: "unknown",
      };
    }
  }

  return null;
}

async function fetchZctaBoundaryGeoJson(zcta: string): Promise<GeoJSONFeatureCollection> {
  if (!ZIP_REGEX.test(zcta)) {
    throw new HttpsError("not-found", "No ZIP boundary found.");
  }

  return fetchBoundaryGeoJson(
    ZCTA_LAYER_ID,
    `ZCTA5='${zcta}'`,
    "ZCTA5,GEOID,NAME"
  );
}

async function fetchTractBoundary(
  tractGeoid: string | null
): Promise<GeoJSONFeatureCollection | null> {
  if (!tractGeoid || !TRACT_REGEX.test(tractGeoid)) {
    return null;
  }

  return fetchBoundaryGeoJson(TRACT_LAYER_ID, `GEOID='${tractGeoid}'`, "GEOID,NAME").catch(
    () => null
  );
}

async function fetchBlockBoundary(
  blockFips: string | null
): Promise<GeoJSONFeatureCollection | null> {
  if (!blockFips || !BLOCK_REGEX.test(blockFips)) {
    return null;
  }

  return fetchBoundaryGeoJson(BLOCK_LAYER_ID, `GEOID='${blockFips}'`, "GEOID,NAME").catch(
    () => null
  );
}

async function fetchBlockFips(latitude: number, longitude: number): Promise<string> {
  const url = new URL(FCC_CENSUS_URL);
  url.searchParams.set("latitude", String(latitude));
  url.searchParams.set("longitude", String(longitude));
  url.searchParams.set("format", "json");

  const decoded = await fetchJson<FCCBlockResponse>(url.toString());
  const fips = decoded.Block?.fips ?? "";
  if (!fips) {
    throw new HttpsError("not-found", "No block FIPS found for this coordinate.");
  }

  return fips;
}

async function fetchBoundaryGeoJson(
  layerId: string,
  whereClause: string,
  outFields: string
): Promise<GeoJSONFeatureCollection> {
  const url = new URL(`${TIGERWEB_MAPSERVER_BASE_URL}/${layerId}/query`);
  url.searchParams.set("where", whereClause);
  url.searchParams.set("outFields", outFields);
  url.searchParams.set("returnGeometry", "true");
  url.searchParams.set("outSR", "4326");
  url.searchParams.set("f", "geojson");

  const raw = await fetchJson<{ type: string; features?: unknown[] }>(url.toString());
  const normalized = normalizeFeatureCollection(raw);

  if (normalized.features.length === 0) {
    throw new HttpsError("not-found", "No boundary features found.");
  }

  return normalized;
}

async function fetchAcsDemographicsForZip(zcta: string): Promise<Demographics> {
  return fetchAcsDemographics(
    `zip code tabulation area:${zcta}`,
    null,
    `ZIP ${zcta}`
  );
}

async function fetchAcsDemographicsForTract(tractGeoid: string): Promise<Demographics> {
  const state = tractGeoid.slice(0, 2);
  const county = tractGeoid.slice(2, 5);
  const tract = tractGeoid.slice(-6);

  return fetchAcsDemographics(
    `tract:${tract}`,
    `state:${state}+county:${county}`,
    `Tract ${tractGeoid}`
  );
}

async function fetchAcsDemographics(
  forQuery: string,
  inQuery: string | null,
  fallbackName: string
): Promise<Demographics> {
  const url = new URL(`https://api.census.gov/data/${ACS_YEAR}/acs/acs5`);
  url.searchParams.set("get", acsExtendedVariables.join(","));
  url.searchParams.set("for", forQuery);
  if (inQuery) {
    url.searchParams.set("in", inQuery);
  }
  if (CENSUS_API_KEY) {
    url.searchParams.set("key", CENSUS_API_KEY);
  }

  const top = await fetchJson<string[][]>(url.toString());
  if (!Array.isArray(top) || top.length < 2) {
    throw new HttpsError("internal", "Unexpected ACS response shape.");
  }

  const header = top[0] ?? [];
  const row = top[1] ?? [];
  if (header.length !== row.length) {
    throw new HttpsError("internal", "ACS header length mismatch.");
  }

  const valuesByKey = new Map<string, string>();
  header.forEach((key, index) => valuesByKey.set(key, row[index] ?? ""));

  const intValue = (key: string): number | null => {
    const value = valuesByKey.get(key);
    if (!value) return null;
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : null;
  };

  const doubleValue = (key: string): number | null => {
    const value = valuesByKey.get(key);
    if (!value) return null;
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : null;
  };

  const percent = (numerator: number | null, denominator: number | null): number | null => {
    if (numerator === null || denominator === null || denominator <= 0) {
      return null;
    }

    return (numerator / denominator) * 100;
  };

  if (!valuesByKey.has("B01003_001E")) {
    throw new HttpsError("not-found", "No demographics returned.");
  }

  const owner = intValue("B25003_002E");
  const renter = intValue("B25003_003E");
  const occupancyTotal =
    owner !== null && renter !== null ? owner + renter : null;
  const workersTotal = intValue("B08301_001E");
  const workersWfh = intValue("B08301_021E");
  const povertyUniverse = intValue("B17001_001E");
  const povertyBelow = intValue("B17001_002E");

  return {
    name: valuesByKey.get("NAME") || fallbackName,
    population: intValue("B01003_001E"),
    medianHouseholdIncome: intValue("B19013_001E"),
    medianAge: doubleValue("B01002_001E"),
    housingUnits: intValue("B25001_001E"),
    medianHomeValue: intValue("B25077_001E"),
    medianGrossRent: intValue("B25064_001E"),
    averageHouseholdSize: doubleValue("B25010_001E"),
    ownerOccupied: owner,
    renterOccupied: renter,
    ownerOccupiedPct: percent(owner, occupancyTotal),
    renterOccupiedPct: percent(renter, occupancyTotal),
    workersTotal,
    workersWfh,
    workersWfhPct: percent(workersWfh, workersTotal),
    povertyUniverse,
    povertyBelow,
    povertyRatePct: percent(povertyBelow, povertyUniverse),
    whiteAlone: intValue("B02001_002E"),
    blackAlone: intValue("B02001_003E"),
    asianAlone: intValue("B02001_005E"),
    hispanicOrLatino: intValue("B03003_003E"),
  };
}

async function fetchJson<T>(url: string): Promise<T> {
  return withExternalCache(url, 10 * 60_000, async () => {
    const response = await fetch(url);
    if (!response.ok) {
      const bodySnippet = (await response.text()).slice(0, 500);
      logger.error("Upstream request failed", { url, status: response.status, bodySnippet });
      throw new HttpsError("internal", `Upstream request failed with status ${response.status}.`);
    }

    return (await response.json()) as T;
  });
}

function normalizeFeatureCollection(raw: {
  type: string;
  features?: unknown[];
}): GeoJSONFeatureCollection {
  const features = Array.isArray(raw.features) ? raw.features : [];
  return {
    type: "FeatureCollection",
    features: features
      .map((feature): GeoJSONFeature | null => {
        if (!feature || typeof feature !== "object") {
          return null;
        }

        const record = feature as Record<string, unknown>;
        return {
          type: "Feature",
          properties: normalizeProperties(record.properties),
          geometry: normalizeGeometry(record.geometry),
        };
      })
      .filter((value): value is GeoJSONFeature => value !== null),
  };
}

function normalizeProperties(
  value: unknown
): Record<string, string | null> | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }

  const normalized: Record<string, string | null> = {};
  for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
    if (item === null || item === undefined) {
      normalized[key] = null;
    } else if (typeof item === "string") {
      normalized[key] = item;
    } else if (typeof item === "number" || typeof item === "boolean") {
      normalized[key] = String(item);
    }
  }

  return normalized;
}

function normalizeGeometry(value: unknown): GeoJSONGeometry | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const record = value as Record<string, unknown>;
  const type = typeof record.type === "string" ? record.type : "Unknown";
  const coordinates = record.coordinates;

  if (type === "Polygon" && Array.isArray(coordinates)) {
    return { type, coordinates: coordinates as GeoJSONPolygonCoordinates };
  }
  if (type === "MultiPolygon" && Array.isArray(coordinates)) {
    return { type, coordinates: coordinates as GeoJSONMultiPolygonCoordinates };
  }

  return { type, coordinates };
}

function makeComparisonTitle(
  bundle: ZipBundleResponse,
  fallbackTitle: string
): string {
  if (bundle.place?.name) {
    return bundle.place.name;
  }
  if (bundle.demographics.name) {
    return bundle.demographics.name;
  }
  if (bundle.zcta) {
    return `ZIP ${bundle.zcta}`;
  }
  return fallbackTitle;
}

function makeComparisonSubtitle(
  bundle: ZipBundleResponse,
  fallbackSubtitle: string
): string {
  const parts: string[] = [];
  if (bundle.county?.name) {
    parts.push(bundle.county.name);
  }
  if (bundle.zcta) {
    parts.push(`ZIP ${bundle.zcta}`);
  }
  if (bundle.tract?.tractCode) {
    parts.push(`Tract ${bundle.tract.tractCode}`);
  }

  return parts.length > 0 ? parts.join(" · ") : fallbackSubtitle;
}

function coordinateKey(latitude: number, longitude: number): string {
  return `${latitude.toFixed(5)},${longitude.toFixed(5)}`;
}

async function withExternalCache<T>(
  key: string,
  ttlMs: number,
  loader: () => Promise<T>
): Promise<T> {
  return externalApiCache.getOrSet(key, ttlMs, loader) as Promise<T>;
}

async function withDerivedCache<T>(
  key: string,
  ttlMs: number,
  loader: () => Promise<T>
): Promise<T> {
  return derivedResponseCache.getOrSet(key, ttlMs, loader) as Promise<T>;
}
