package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * One checkpoint along a route polyline from /CheckPoint.
 */
public record CheckPoint(
        @JsonProperty("PointID") String pointId,
        @JsonProperty("latitude") double latitude,
        @JsonProperty("longitude") double longitude,
        @JsonProperty("routeid") int routeid
) {}