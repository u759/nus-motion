package com.nusmotion.backend.dto;

/**
 * Response DTO for the "nearest bus stop to a building" endpoint.
 *
 * LEARNING NOTE:
 * - This record is NOT mapped from an upstream API — we CREATE it ourselves.
 *   The service layer computes the nearest stop using the Haversine formula,
 *   then assembles this record from building + bus stop data.
 * - We include both the building and the bus stop coordinates so the Flutter
 *   frontend can draw a line between them on the map.
 * - distanceMeters tells the user how far the walk is (straight-line distance).
 */
public record NearestStopResult(
        String buildingName,
        double buildingLatitude,
        double buildingLongitude,
        String busStopName,
        String busStopDisplayName,
        double busStopLatitude,
        double busStopLongitude,
        double distanceMeters
) {}
