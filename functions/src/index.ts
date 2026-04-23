import {
  buildComparisonProfile,
  buildDemographicsForScale,
  buildNeighborhoodBoundaries,
  buildPlaceProfile,
  buildZipBundle,
  onCallLociq,
} from "./lociqBackend.js";

export const getLociqZipBundle = onCallLociq(async (request) => {
  const { latitude, longitude, locale } = request;
  return buildZipBundle(latitude, longitude, locale);
});

export const getLociqNeighborhoodBoundaries = onCallLociq(async (request) => {
  const { latitude, longitude, tractGeoid, zcta } = request;
  return buildNeighborhoodBoundaries(latitude, longitude, tractGeoid ?? null, zcta ?? null);
});

export const getLociqDemographics = onCallLociq(async (request) => {
  const { latitude, longitude, scale, zcta, tractGeoid } = request;
  return buildDemographicsForScale(latitude, longitude, scale, zcta ?? null, tractGeoid ?? null);
});

export const getLociqPlaceProfile = onCallLociq(async (request) => {
  const { latitude, longitude, locale } = request;
  return buildPlaceProfile(latitude, longitude, locale);
});

export const getLociqComparison = onCallLociq(async (request) => {
  const { latitude, longitude, scale, fallbackTitle, fallbackSubtitle } = request;
  return buildComparisonProfile(
    latitude,
    longitude,
    scale,
    fallbackTitle ?? "",
    fallbackSubtitle ?? ""
  );
});
