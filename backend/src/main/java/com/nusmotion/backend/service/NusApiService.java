package com.nusmotion.backend.service;

import com.nusmotion.backend.dto.*;
import com.nusmotion.backend.dto.Wrappers.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

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
 * YOUR TASKS:
 * ───────────
 * TODO 1: Add getCheckpoints(String routeCode) → returns route polyline points
 * TODO 2: Add getAnnouncements() → returns service disruption alerts
 * TODO 3: Add getRouteMinMaxTime(String routeCode) → returns operating hours
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
}
