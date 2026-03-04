package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Real-time GPS location of an active bus on a route.
 */
public record ActiveBus(
        @JsonProperty("vehplate")
        @JsonAlias("veh_plate") String vehPlate,
        @JsonProperty("lat") double lat,
        @JsonProperty("lng") double lng,
        @JsonProperty("speed") int speed,
        @JsonProperty("direction") double direction,
        @JsonProperty("loadInfo") LoadInfo loadInfo
) {

    /**
     * Real-time passenger load information for a bus.
     */
    public record LoadInfo(
            @JsonProperty("occupancy") double occupancy,
            @JsonProperty("crowdLevel") String crowdLevel,
            @JsonProperty("capacity") int capacity,
            @JsonProperty("ridership") int ridership
    ) {}
}
