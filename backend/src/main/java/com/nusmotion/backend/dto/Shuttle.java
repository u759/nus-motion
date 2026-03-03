package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * One shuttle service at a bus stop (arrival time, passenger load, etc.).
 */
public record Shuttle(
        @JsonProperty("name") String name,
        @JsonProperty("arrivalTime") String arrivalTime,
        @JsonProperty("arrivalTime_veh_plate") String arrivalTimeVehPlate,
        @JsonProperty("nextArrivalTime") String nextArrivalTime,
        @JsonProperty("nextArrivalTime_veh_plate") String nextArrivalTimeVehPlate,
        @JsonProperty("passengers") String passengers,
        @JsonProperty("nextPassengers") String nextPassengers
) {}
