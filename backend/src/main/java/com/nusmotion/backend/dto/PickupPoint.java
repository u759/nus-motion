package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Pickup point for a route from /PickupPoint.
 */
public record PickupPoint(
        @JsonProperty("busstopcode") String busstopcode,
        @JsonProperty("LongName") String longName,
        @JsonProperty("ShortName") String shortName,
        @JsonProperty("lat") double lat,
        @JsonProperty("lng") double lng,
        @JsonProperty("pickupname") String pickupname,
        @JsonProperty("routeid") int routeid
) {}
