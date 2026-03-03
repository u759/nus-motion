package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * Wrapper DTOs that mirror the upstream API's nested JSON structure.
 *
 * LEARNING NOTE:
 * - The NUS API wraps every response in a "...Result" object.  We need matching
 *   wrapper records so Jackson can navigate the nesting automatically.
 * - Using nested records keeps each wrapper close to its inner type.
 */
public final class Wrappers {

    private Wrappers() {} // utility class

    // ── /BusStops ──
    public record BusStopsResponse(
            @JsonProperty("BusStopsResult") BusStopsResult busStopsResult) {}

    public record BusStopsResult(
            @JsonProperty("busstops") List<BusStop> busStops) {}

    // ── /ShuttleService ──
    public record ShuttleServiceResponse(
            @JsonProperty("ShuttleServiceResult") ShuttleServiceResult shuttleServiceResult) {}

    public record ShuttleServiceResult(
            @JsonProperty("name") String name,
            @JsonProperty("caption") String caption,
            @JsonProperty("shuttles") List<Shuttle> shuttles) {}

    // ── /ActiveBus ──
    public record ActiveBusResponse(
            @JsonProperty("ActiveBusResult") ActiveBusResult activeBusResult) {}

    public record ActiveBusResult(
            @JsonProperty("ActiveBusCount") String activeBusCount,
            @JsonProperty("activebus") List<ActiveBus> activeBuses) {}
}
