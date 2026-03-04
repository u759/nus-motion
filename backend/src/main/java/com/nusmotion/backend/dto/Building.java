package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Maps one building from the NUS Digital Twin API response.
 *
 * LEARNING NOTE:
 * - This record matches the JSON structure returned by the upstream API:
 *   { "elementId": "732229053", "name": "Cendana College",
 *     "address": "28 College Avenue West", "postal": "138533",
 *     "latitude": 1.30814, "longitude": 103.77248 }
 * - The upstream data may have DUPLICATE buildings (same name, slightly different
 *   coordinates).  We handle deduplication in the service layer.
 */
public record Building(
        @JsonProperty("elementId") String elementId,
        @JsonProperty("name") String name,
        @JsonProperty("address") String address,
        @JsonProperty("postal") String postal,
        @JsonProperty("latitude") double latitude,
        @JsonProperty("longitude") double longitude
) {}
