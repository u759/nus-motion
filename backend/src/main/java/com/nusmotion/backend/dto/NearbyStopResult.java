package com.nusmotion.backend.dto;

/**
 * Nearby bus stop result for geolocation search.
 */
public record NearbyStopResult(
        String stopName,
        String stopDisplayName,
        double latitude,
        double longitude,
        double distanceMeters,
        int walkingMinutes
) {}
