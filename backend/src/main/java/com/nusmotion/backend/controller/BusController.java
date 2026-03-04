package com.nusmotion.backend.controller;

import com.nusmotion.backend.dto.*;
import com.nusmotion.backend.dto.Wrappers.ShuttleServiceResult;
import com.nusmotion.backend.service.NusApiService;
import com.nusmotion.backend.service.RoutingService;
import com.nusmotion.backend.service.WeatherService;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClientResponseException;

import java.util.List;
import java.util.Map;

/**
 * REST controller that exposes the proxied NUS bus data to the Flutter frontend.
 *
 * LEARNING NOTES:
 *
 * 1. @RestController = @Controller + @ResponseBody
 *    Every method return value is automatically serialized to JSON.
 *
 * 2. @RequestMapping("/api") sets a common prefix for all endpoints in this class.
 *    Combined with @GetMapping on each method, the full path becomes e.g. /api/stops.
 *
 * 3. @CrossOrigin allows the Flutter web build (or any browser client) to call
 *    these endpoints.  Without it, browsers block cross-origin requests.
 *
 * 4. @RequestParam maps query string parameters.  For example:
 *    GET /api/shuttles?stop=UTown  →  getShuttles("UTown")
 *
 * YOUR TASKS:
 * ───────────
 * TODO 1: Add GET /api/checkpoints?route=A1 → return route polyline
 * TODO 2: Add GET /api/announcements → return service alerts
 * TODO 3: Add GET /api/schedule?route=A1 → return operating hours
 */
@RestController
@RequestMapping("/api")
@CrossOrigin
public class BusController {

    private final NusApiService nusApiService;
    private final RoutingService routingService;
    private final WeatherService weatherService;

    public BusController(NusApiService nusApiService,
                         RoutingService routingService,
                         WeatherService weatherService) {
        this.nusApiService = nusApiService;
        this.routingService = routingService;
        this.weatherService = weatherService;
    }

    @GetMapping("/stops")
    public List<BusStop> getStops() {
        return nusApiService.getBusStops();
    }

    @GetMapping("/shuttles")
    public ShuttleServiceResult getShuttles(@RequestParam("stop") String busstopname) {
        return nusApiService.getShuttleService(busstopname);
    }

    @GetMapping("/active-buses")
    public List<ActiveBus> getActiveBuses(@RequestParam("route") String routeCode) {
        return nusApiService.getActiveBuses(routeCode);
    }

    @GetMapping("/checkpoints")
    public List<CheckPoint> getCheckpoints(@RequestParam("route") String routeCode) {
        return nusApiService.getCheckpoints(routeCode);
    }

    @GetMapping("/announcements")
    public List<Announcement> getAnnouncements() {
        return nusApiService.getAnnouncements();
    }

    @GetMapping("/schedule")
    public List<RouteSchedule> getSchedule(@RequestParam("route") String routeCode) {
        return nusApiService.getRouteMinMaxTime(routeCode);
    }

    @GetMapping("/service-descriptions")
    public List<ServiceDescription> getServiceDescriptions() {
        return nusApiService.getServiceDescriptions();
    }

    @GetMapping("/pickup-points")
    public List<PickupPoint> getPickupPoints(@RequestParam("route") String routeCode) {
        return nusApiService.getPickupPoints(routeCode);
    }

    @GetMapping("/ticker-tapes")
    public List<TickerTape> getTickerTapes() {
        return nusApiService.getTickerTapes();
    }

    /**
     * Experimental passthrough. Upstream currently returns 500 on this endpoint.
     */
    @GetMapping("/publicity")
    public ResponseEntity<String> getPublicity() {
        try {
            return ResponseEntity.ok()
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(nusApiService.getPublicity());
        } catch (RestClientResponseException e) {
            return ResponseEntity.status(502)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body("{\"error\":\"Upstream /publicity unavailable\",\"upstreamStatus\":" + e.getStatusCode().value() + "}");
        }
    }

    /**
     * Experimental passthrough. Upstream currently returns 500 on this endpoint.
     * Optional query params: route, stop.
     */
    @GetMapping("/bus-location")
    public ResponseEntity<String> getBusLocation(
            @RequestParam(value = "route", required = false) String routeCode,
            @RequestParam(value = "stop", required = false) String busstopname) {
        try {
            return ResponseEntity.ok()
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(nusApiService.getBusLocation(routeCode, busstopname));
        } catch (RestClientResponseException e) {
            return ResponseEntity.status(502)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body("{\"error\":\"Upstream /BusLocation unavailable\",\"upstreamStatus\":" + e.getStatusCode().value() + "}");
        }
    }

    /**
     * Nearby stops by geolocation.
     */
    @GetMapping("/nearby-stops")
    public List<NearbyStopResult> getNearbyStops(
            @RequestParam("lat") double latitude,
            @RequestParam("lng") double longitude,
            @RequestParam(value = "radius", defaultValue = "800") int radiusMeters,
            @RequestParam(value = "limit", defaultValue = "5") int limit) {
        return routingService.getNearbyStops(latitude, longitude, radiusMeters, limit);
    }

    /**
     * Route planning between two searched places (bus stop/building).
     */
    @GetMapping("/route")
    public ResponseEntity<?> getRoute(
            @RequestParam("from") String from,
            @RequestParam("to") String to) {
        try {
            return ResponseEntity.ok(routingService.planRoute(from, to));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        } catch (IllegalStateException e) {
            return ResponseEntity.status(422).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Weather summary from Open-Meteo based on current location.
     */
    @GetMapping("/weather")
    public WeatherSnapshot getWeather(
            @RequestParam("lat") double latitude,
            @RequestParam("lng") double longitude) {
        return weatherService.getWeather(latitude, longitude);
    }
}
