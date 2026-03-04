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

    // ── /CheckPoint ──
    public record CheckPointResponse(
            @JsonProperty("CheckPointResult") CheckPointResult checkPointResult) {}

    public record CheckPointResult(
            @JsonProperty("CheckPoint") List<CheckPoint> checkPoints) {}

    // ── /Announcements ──
    public record AnnouncementsResponse(
            @JsonProperty("AnnouncementsResult") AnnouncementsResult announcementsResult) {}

    public record AnnouncementsResult(
            @JsonProperty("Announcement") List<Announcement> announcements) {}

    // ── /RouteMinMaxTime ──
    public record RouteMinMaxTimeResponse(
            @JsonProperty("RouteMinMaxTimeResult") RouteMinMaxTimeResult routeMinMaxTimeResult) {}

    public record RouteMinMaxTimeResult(
            @JsonProperty("RouteMinMaxTime") List<RouteSchedule> routeSchedules) {}

    // ── /ServiceDescription ──
    public record ServiceDescriptionResponse(
            @JsonProperty("ServiceDescriptionResult") ServiceDescriptionResult serviceDescriptionResult) {}

    public record ServiceDescriptionResult(
            @JsonProperty("ServiceDescription") List<ServiceDescription> serviceDescriptions) {}

    // ── /PickupPoint ──
    public record PickupPointResponse(
            @JsonProperty("PickupPointResult") PickupPointResult pickupPointResult) {}

    public record PickupPointResult(
            @JsonProperty("pickuppoint") List<PickupPoint> pickupPoints) {}

    // ── /TickerTapes ──
    public record TickerTapesResponse(
            @JsonProperty("TickerTapesResult") TickerTapesResult tickerTapesResult) {}

    public record TickerTapesResult(
            @JsonProperty("TickerTape") List<TickerTape> tickerTapes) {}
}
