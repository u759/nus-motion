package com.nusmotion.backend.service;

import com.nusmotion.backend.dto.*;
import com.nusmotion.backend.dto.Wrappers.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.List;

/**
 * Fetches data from the upstream NUS NextBus API and caches results.
 *
 * LEARNING NOTES — READ THESE CAREFULLY:
 *
 * 1. @Service marks this as a Spring-managed bean.  Spring creates exactly ONE
 *    instance (singleton scope by default) and injects it wherever needed.
 *
 * 2. Constructor injection: the RestClient bean we defined in WebClientConfig
 *    is passed in automatically.  No @Autowired needed when there's a single
 *    constructor.
 *
 * 3. @Cacheable("busStops") means:
 *    - First call → executes the method body → stores result in cache "busStops"
 *    - Subsequent calls (within TTL) → returns cached value, method body SKIPPED
 *    - After TTL expires → cache evicts entry → next call fetches fresh data
 *    This is why we set up Caffeine with expireAfterWrite(10s) in CacheConfig.
 *
 * 4. RestClient call chain:
 *    .get()                         → HTTP GET
 *    .uri("/BusStops")              → appended to baseUrl from WebClientConfig
 *    .retrieve()                    → send request
 *    .body(Wrapper.class)           → deserialize JSON into our DTO
 *
 * NEW INTEGRATION NOTES:
 * - This service now supports ALL stable endpoints from docs/nus-nextbus-openapi.yaml.
 * - We also expose experimental passthroughs for /publicity and /BusLocation.
 *   (These currently return upstream 500 at the source API, but wiring is in place.)
 */
@Service
public class NusApiService {

    private static final Logger log = LoggerFactory.getLogger(NusApiService.class);

    private final RestClient nusApiClient;

    public NusApiService(RestClient nusApiClient) {
        this.nusApiClient = nusApiClient;
    }

    /**
     * Fetch all bus stops. Cached because stop data rarely changes.
     */
    @Cacheable("busStops")
    public List<BusStop> getBusStops() {
        log.debug("Cache MISS — fetching /BusStops from upstream");
        BusStopsResponse response = nusApiClient.get()
                .uri("/BusStops")
                .retrieve()
                .body(BusStopsResponse.class);
        return response != null ? response.busStopsResult().busStops() : List.of();
    }

    /**
     * Fetch live shuttle arrivals at a specific stop.
     * Key = busstopname so each stop is cached independently.
     */
    @Cacheable(value = "shuttleService", key = "#busstopname")
    public ShuttleServiceResult getShuttleService(String busstopname) {
        log.debug("Cache MISS — fetching /ShuttleService?busstopname={}", busstopname);
        ShuttleServiceResponse response = nusApiClient.get()
                .uri("/ShuttleService?busstopname={stop}", busstopname)
                .retrieve()
                .body(ShuttleServiceResponse.class);
        return response != null ? response.shuttleServiceResult() : null;
    }

    /**
     * Fetch real-time GPS positions of all buses on a route.
     */
    @Cacheable(value = "activeBuses", key = "#routeCode")
    public List<ActiveBus> getActiveBuses(String routeCode) {
        log.debug("Cache MISS — fetching /ActiveBus?route_code={}", routeCode);
        ActiveBusResponse response = nusApiClient.get()
                .uri("/ActiveBus?route_code={route}", routeCode)
                .retrieve()
                .body(ActiveBusResponse.class);
        return response != null && response.activeBusResult() != null
                ? response.activeBusResult().activeBuses()
                : List.of();
    }

    /**
     * Fetch route checkpoints (polyline) for map rendering.
     */
    @Cacheable(value = "checkpoints", key = "#routeCode")
    public List<CheckPoint> getCheckpoints(String routeCode) {
        log.debug("Cache MISS — fetching /CheckPoint?route_code={}", routeCode);
        CheckPointResponse response = nusApiClient.get()
                .uri("/CheckPoint?route_code={route}", routeCode)
                .retrieve()
                .body(CheckPointResponse.class);
        return response != null
                && response.checkPointResult() != null
                && response.checkPointResult().checkPoints() != null
                ? response.checkPointResult().checkPoints()
                : List.of();
    }

    /**
     * Fetch service announcements.
     */
    @Cacheable("announcements")
    public List<Announcement> getAnnouncements() {
        log.debug("Cache MISS — fetching /Announcements");
        AnnouncementsResponse response = nusApiClient.get()
                .uri("/Announcements")
                .retrieve()
                .body(AnnouncementsResponse.class);
        return response != null
                && response.announcementsResult() != null
                && response.announcementsResult().announcements() != null
                ? response.announcementsResult().announcements()
                : List.of();
    }

    /**
     * Fetch route first/last bus timings by day type.
     */
    @Cacheable(value = "schedule", key = "#routeCode")
    public List<RouteSchedule> getRouteMinMaxTime(String routeCode) {
        log.debug("Cache MISS — fetching /RouteMinMaxTime?route_code={}", routeCode);
        RouteMinMaxTimeResponse response = nusApiClient.get()
                .uri("/RouteMinMaxTime?route_code={route}", routeCode)
                .retrieve()
                .body(RouteMinMaxTimeResponse.class);
        return response != null
                && response.routeMinMaxTimeResult() != null
                && response.routeMinMaxTimeResult().routeSchedules() != null
                ? response.routeMinMaxTimeResult().routeSchedules()
                : List.of();
    }

    /**
     * Fetch route descriptions.
     */
    @Cacheable("serviceDescriptions")
    public List<ServiceDescription> getServiceDescriptions() {
        log.debug("Cache MISS — fetching /ServiceDescription");
        ServiceDescriptionResponse response = nusApiClient.get()
                .uri("/ServiceDescription")
                .retrieve()
                .body(ServiceDescriptionResponse.class);
        return response != null
                && response.serviceDescriptionResult() != null
                && response.serviceDescriptionResult().serviceDescriptions() != null
                ? response.serviceDescriptionResult().serviceDescriptions()
                : List.of();
    }

    /**
     * Fetch pickup points for a route.
     */
    @Cacheable(value = "pickupPoints", key = "#routeCode")
    public List<PickupPoint> getPickupPoints(String routeCode) {
        log.debug("Cache MISS — fetching /PickupPoint?route_code={}", routeCode);
        PickupPointResponse response = nusApiClient.get()
                .uri("/PickupPoint?route_code={route}", routeCode)
                .retrieve()
                .body(PickupPointResponse.class);
        return response != null
                && response.pickupPointResult() != null
                && response.pickupPointResult().pickupPoints() != null
                ? response.pickupPointResult().pickupPoints()
                : List.of();
    }

    /**
     * Fetch ticker tapes (alerts with optional geolocation).
     */
    @Cacheable("tickerTapes")
    public List<TickerTape> getTickerTapes() {
        log.debug("Cache MISS — fetching /TickerTapes");
        TickerTapesResponse response = nusApiClient.get()
                .uri("/TickerTapes")
                .retrieve()
                .body(TickerTapesResponse.class);
        return response != null
                && response.tickerTapesResult() != null
                && response.tickerTapesResult().tickerTapes() != null
                ? response.tickerTapesResult().tickerTapes()
                : List.of();
    }

    /**
     * Experimental passthrough endpoint. Upstream currently returns 500.
     */
    @Cacheable("publicity")
        public String getPublicity() {
        log.debug("Cache MISS — fetching /publicity");
        return nusApiClient.get()
                .uri("/publicity")
                .retrieve()
                                .body(String.class);
    }

    /**
     * Experimental passthrough endpoint. Upstream currently returns 500.
     * Accepts optional route_code and busstopname.
     */
    @Cacheable(value = "busLocation", key = "(#routeCode == null ? '' : #routeCode) + '|' + (#busstopname == null ? '' : #busstopname)")
        public String getBusLocation(String routeCode, String busstopname) {
        String uri = UriComponentsBuilder.fromPath("/BusLocation")
                .queryParamIfPresent("route_code", java.util.Optional.ofNullable(routeCode))
                .queryParamIfPresent("busstopname", java.util.Optional.ofNullable(busstopname))
                .build()
                .encode()
                .toUriString();
        log.debug("Cache MISS — fetching {}", uri);
        return nusApiClient.get()
                .uri(uri)
                .retrieve()
                                .body(String.class);
    }
}
