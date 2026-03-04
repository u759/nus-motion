package com.nusmotion.backend.service;

import com.nusmotion.backend.dto.Building;
import com.nusmotion.backend.dto.BusStop;
import com.nusmotion.backend.dto.NearestStopResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Fetches NUS building data and computes nearest bus stop.
 *
 * LEARNING NOTES — READ THESE CAREFULLY:
 *
 * 1. This service talks to a DIFFERENT upstream API (NUS Digital Twin) than
 *    NusApiService (NUS NextBus).  We create a separate RestClient because
 *    the base URL and auth headers are different (no auth needed here).
 *
 * 2. The Digital Twin API returns a flat JSON array (not wrapped in an envelope),
 *    so we use ParameterizedTypeReference<List<Building>> to deserialize directly.
 *
 * 3. DEDUPLICATION: The upstream data has duplicate entries (same building name,
 *    slightly different GPS coordinates).  We keep the first occurrence per name.
 *    This uses Java Streams + Collectors.toMap with a merge function.
 *
 * 4. HAVERSINE FORMULA: Computes the great-circle distance between two lat/lng
 *    points on the Earth's surface.  This gives us straight-line distance in meters,
 *    which is good enough for "nearest bus stop" since NUS campus is small.
 *
 * 5. We reuse NusApiService.getBusStops() to get the bus stop list (which is
 *    already cached).  This is DEPENDENCY INJECTION at work — one service
 *    calling another, both managed by Spring.
 *
 * STEP-BY-STEP HOW TO BUILD THIS (for learning):
 * ────────────────────────────────────────────────
 * Step 1: Create this file with just the class skeleton and constructor.
 * Step 2: Add getBuildings() — fetch from upstream, cache the result.
 * Step 3: Add the Haversine helper method (pure math, no Spring needed).
 * Step 4: Add findNearestStop() — combine buildings + bus stops + Haversine.
 * Step 5: Test each step by running the app and hitting the endpoint with curl.
 */
@Service
public class BuildingService {

    private static final Logger log = LoggerFactory.getLogger(BuildingService.class);

    /**
     * Earth's mean radius in meters — used by the Haversine formula.
     * This is a constant because the Earth doesn't change size ;)
     */
    private static final double EARTH_RADIUS_METERS = 6_371_000;

    private final RestClient buildingsClient;
    private final NusApiService nusApiService;

    /**
     * LEARNING NOTE — Constructor Injection:
     * - @Value reads a single property from application.properties.
     *   We use it here instead of @ConfigurationProperties because we only
     *   need one value (the URL), not a group of related properties.
     * - NusApiService is injected so we can call getBusStops() to find the
     *   nearest stop.  Spring resolves the dependency automatically.
     */
    public BuildingService(@Value("${nus.buildings.url}") String buildingsUrl,
                           NusApiService nusApiService) {
        this.buildingsClient = RestClient.builder()
                .baseUrl(buildingsUrl)
                .build();
        this.nusApiService = nusApiService;
    }

    /**
     * Fetch all NUS buildings, deduplicated by name.
     *
     * LEARNING NOTE:
     * - The upstream returns ~3000 entries with many duplicates.
     * - We deduplicate by using Collectors.toMap with name as key.
     *   The merge function (existing, duplicate) -> existing keeps the first one.
     * - LinkedHashMap preserves insertion order so results are consistent.
     * - Cache TTL is 1 hour (configured in CacheConfig) because buildings don't move.
     */
    @Cacheable("buildings")
    public List<Building> getBuildings() {
        log.debug("Cache MISS — fetching buildings from NUS Digital Twin API");
        List<Building> raw = buildingsClient.get()
                .retrieve()
                .body(new ParameterizedTypeReference<List<Building>>() {});

        if (raw == null) return List.of();

        // Deduplicate: keep first entry per building name
        Map<String, Building> unique = raw.stream()
                .collect(Collectors.toMap(
                        Building::name,           // key = building name
                        b -> b,                   // value = the Building itself
                        (existing, duplicate) -> existing,  // on conflict: keep first
                        LinkedHashMap::new         // preserve insertion order
                ));

        log.debug("Deduplicated {} raw entries → {} unique buildings", raw.size(), unique.size());
        return List.copyOf(unique.values());
    }

    /**
     * Find the nearest bus stop to a building by name.
     *
     * LEARNING NOTE — Algorithm:
     * 1. Look up the building by name (case-insensitive search).
     * 2. Get all bus stops from NusApiService (already cached).
     * 3. For each bus stop, compute the Haversine distance to the building.
     * 4. Return the bus stop with the smallest distance.
     *
     * @param buildingName The name of the building to search for.
     * @return NearestStopResult with building coords, stop coords, and distance.
     * @throws IllegalArgumentException if the building name is not found.
     */
    public NearestStopResult findNearestStop(String buildingName) {
        List<Building> buildings = getBuildings();

        // Case-insensitive search for the building
        Building building = buildings.stream()
                .filter(b -> b.name().equalsIgnoreCase(buildingName))
                .findFirst()
                .orElse(null);

        if (building == null) {
            throw new IllegalArgumentException("Building not found: " + buildingName);
        }

        List<BusStop> stops = nusApiService.getBusStops();
        if (stops.isEmpty()) {
            throw new IllegalStateException("No bus stops available");
        }

        // Find the closest bus stop using Haversine distance
        BusStop nearest = stops.stream()
                .min(Comparator.comparingDouble(stop ->
                        haversine(building.latitude(), building.longitude(),
                                  stop.latitude(), stop.longitude())))
                .orElseThrow();

        double distance = haversine(
                building.latitude(), building.longitude(),
                nearest.latitude(), nearest.longitude());

        log.debug("Nearest stop to '{}' is '{}' ({} m)",
                buildingName, nearest.longName(), Math.round(distance));

        return new NearestStopResult(
                building.name(),
                building.latitude(),
                building.longitude(),
                nearest.name(),
                nearest.longName(),
                nearest.latitude(),
                nearest.longitude(),
                Math.round(distance)
        );
    }

    /**
     * Haversine formula — computes great-circle distance between two GPS points.
     *
     * LEARNING NOTE:
     * - This is pure math, no Spring involved.  Good candidate for a static method.
     * - Formula: d = 2r × arcsin(√(sin²(Δlat/2) + cos(lat1)·cos(lat2)·sin²(Δlng/2)))
     * - Returns distance in METERS.
     * - Math.toRadians() converts degrees → radians (GPS uses degrees).
     *
     * @param lat1 Latitude of point 1 (degrees)
     * @param lng1 Longitude of point 1 (degrees)
     * @param lat2 Latitude of point 2 (degrees)
     * @param lng2 Longitude of point 2 (degrees)
     * @return Distance in meters
     */
    static double haversine(double lat1, double lng1, double lat2, double lng2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);

        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(dLng / 2) * Math.sin(dLng / 2);

        double c = 2 * Math.asin(Math.sqrt(a));

        return EARTH_RADIUS_METERS * c;
    }
}
