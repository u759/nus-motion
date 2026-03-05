package com.nusmotion.backend.service;

import com.nusmotion.backend.dto.*;
import com.nusmotion.backend.dto.Wrappers.ShuttleServiceResult;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Routing + nearby-stop computation service.
 *
 * This service provides:
 * 1) Nearby stops by lat/lng
 * 2) Route planning between two searched places (bus stop or building)
 *
 * Route planning strategy:
 * - Try direct routes first (0 transfer)
 * - Then try one-transfer routes
 * - Score each candidate using: walk + wait + bus + transfer penalty
 */
@Service
public class RoutingService {

    private static final double EARTH_RADIUS_METERS = 6_371_000;
    private static final double WALK_SPEED_MPS = 1.3;      // ~4.7 km/h
    private static final double BUS_SPEED_MPS = 4.8;       // ~17.3 km/h average campus speed
    private static final double WALK_TIME_BUFFER = 1.15;   // user-friendly buffer
    private static final double BUS_TIME_BUFFER = 1.20;    // traffic/stops buffer
    private static final int DWELL_SECONDS_PER_STOP = 20;
    private static final int TRANSFER_PENALTY_MIN = 3;
    private static final int DEFAULT_WAIT_MIN = 6;
    private static final int SEARCH_RADIUS_METERS = 800;
    private static final int CANDIDATE_LIMIT = 5;

    private static final Pattern ETA_DIGIT_PATTERN = Pattern.compile("(\\d+)");

    private final NusApiService nusApiService;
    private final BuildingService buildingService;

    public RoutingService(NusApiService nusApiService, BuildingService buildingService) {
        this.nusApiService = nusApiService;
        this.buildingService = buildingService;
    }

    @Cacheable(value = "nearbyStops", key = "#lat + '|' + #lng + '|' + #radiusMeters + '|' + #limit")
    public List<NearbyStopResult> getNearbyStops(double lat, double lng, int radiusMeters, int limit) {
        int effectiveRadius = Math.max(50, radiusMeters);
        int effectiveLimit = Math.max(1, limit);

        return nusApiService.getBusStops().stream()
                .map(stop -> {
                    double distance = haversine(lat, lng, stop.latitude(), stop.longitude());
                    int walkMin = walkingMinutes(distance);
                    return new NearbyStopResult(
                            stop.name(),
                            stop.longName(),
                            stop.latitude(),
                            stop.longitude(),
                            Math.round(distance),
                            walkMin
                    );
                })
                .filter(item -> item.distanceMeters() <= effectiveRadius)
                .sorted(Comparator.comparingDouble(NearbyStopResult::distanceMeters))
                .limit(effectiveLimit)
                .toList();
    }

    @Cacheable(value = "routePlans", key = "#from + '|' + #to")
    public RoutePlanResult planRoute(String from, String to) {
        Location origin = resolveLocation(from);
        Location destination = resolveLocation(to);

        List<BusStop> allStops = nusApiService.getBusStops();
        List<CandidateStop> originCandidates = candidateStops(origin.latitude, origin.longitude, allStops, SEARCH_RADIUS_METERS, CANDIDATE_LIMIT);
        List<CandidateStop> destinationCandidates = candidateStops(destination.latitude, destination.longitude, allStops, SEARCH_RADIUS_METERS, CANDIDATE_LIMIT);

        // Fallback if no stops within search radius: use nearest stop only.
        if (originCandidates.isEmpty()) {
            originCandidates = candidateStops(origin.latitude, origin.longitude, allStops, Integer.MAX_VALUE, 1);
        }
        if (destinationCandidates.isEmpty()) {
            destinationCandidates = candidateStops(destination.latitude, destination.longitude, allStops, Integer.MAX_VALUE, 1);
        }

        Map<String, RoutePath> routePaths = buildRoutePaths(allStops);

        PlanCandidate best = null;

        // 1) Try direct routes (0 transfer)
        for (RoutePath path : routePaths.values()) {
            for (CandidateStop o : originCandidates) {
                int originIdx = path.indexOfStop(o.stop.name());
                if (originIdx < 0) continue;

                for (CandidateStop d : destinationCandidates) {
                    int destIdx = path.indexOfStop(d.stop.name());
                    if (destIdx <= originIdx) continue;

                    int walkOrigin = o.walkMinutes;
                    int wait = estimateWaitMinutes(o.stop.name(), path.routeCode);
                    int bus = estimateBusTravelMinutes(path, originIdx, destIdx);
                    int walkDest = d.walkMinutes;

                    int total = walkOrigin + wait + bus + walkDest;
                    List<RouteLeg> legs = buildDirectLegs(path.routeCode, o, d, walkOrigin, wait, bus, walkDest);

                    PlanCandidate candidate = new PlanCandidate(total, walkOrigin + walkDest, wait, bus, 0, legs);
                    if (isBetter(candidate, best)) best = candidate;
                }
            }
        }

        // 2) Try one-transfer routes
        for (RoutePath pathA : routePaths.values()) {
            for (RoutePath pathB : routePaths.values()) {
                if (pathA.routeCode.equals(pathB.routeCode)) continue;

                for (CandidateStop o : originCandidates) {
                    int originIdx = pathA.indexOfStop(o.stop.name());
                    if (originIdx < 0) continue;

                    for (CandidateStop d : destinationCandidates) {
                        int destIdx = pathB.indexOfStop(d.stop.name());
                        if (destIdx < 0) continue;

                        for (String transferStopName : pathA.commonStops(pathB)) {
                            int transferIdxA = pathA.indexOfStop(transferStopName);
                            int transferIdxB = pathB.indexOfStop(transferStopName);

                            // Need forward direction on both routes.
                            if (transferIdxA <= originIdx || transferIdxB >= destIdx) continue;

                            int walkOrigin = o.walkMinutes;
                            int waitA = estimateWaitMinutes(o.stop.name(), pathA.routeCode);
                            int busA = estimateBusTravelMinutes(pathA, originIdx, transferIdxA);

                            int waitB = TRANSFER_PENALTY_MIN + estimateWaitMinutes(transferStopName, pathB.routeCode);
                            int busB = estimateBusTravelMinutes(pathB, transferIdxB, destIdx);
                            int walkDest = d.walkMinutes;

                            int total = walkOrigin + waitA + busA + waitB + busB + walkDest;
                            List<RouteLeg> legs = buildTransferLegs(pathA.routeCode, pathB.routeCode, o, d,
                                    transferStopName, walkOrigin, waitA, busA, waitB, busB, walkDest);

                            PlanCandidate candidate = new PlanCandidate(total, walkOrigin + walkDest, waitA + waitB,
                                    busA + busB, 1, legs);
                            if (isBetter(candidate, best)) best = candidate;
                        }
                    }
                }
            }
        }

        if (best == null) {
            throw new IllegalStateException("No route could be computed with current data");
        }

        return new RoutePlanResult(
                origin.name,
                destination.name,
                best.totalMinutes,
                best.walkingMinutes,
                best.waitingMinutes,
                best.busMinutes,
                best.transfers,
                best.legs
        );
    }

    private List<RouteLeg> buildDirectLegs(String routeCode, CandidateStop originStop, CandidateStop destinationStop,
                                           int walkOrigin, int wait, int bus, int walkDest) {
        List<RouteLeg> legs = new ArrayList<>();

        if (walkOrigin > 0) {
            legs.add(new RouteLeg(
                    "WALK",
                    "Walk to " + originStop.stop.longName(),
                    walkOrigin,
                    null,
                    null,
                    originStop.stop.longName(),
                    null,
                    null,
                    originStop.stop.latitude(),
                    originStop.stop.longitude()
            ));
        }

        legs.add(new RouteLeg(
                "WAIT",
                "Wait for " + routeCode,
                wait,
                routeCode,
                originStop.stop.longName(),
                originStop.stop.longName(),
                originStop.stop.latitude(),
                originStop.stop.longitude(),
                originStop.stop.latitude(),
                originStop.stop.longitude()
        ));

        legs.add(new RouteLeg(
                "BUS",
                routeCode + " from " + originStop.stop.longName() + " to " + destinationStop.stop.longName(),
                bus,
                routeCode,
                originStop.stop.longName(),
                destinationStop.stop.longName(),
                originStop.stop.latitude(),
                originStop.stop.longitude(),
                destinationStop.stop.latitude(),
                destinationStop.stop.longitude()
        ));

        if (walkDest > 0) {
            legs.add(new RouteLeg(
                    "WALK",
                    "Walk to destination",
                    walkDest,
                    null,
                    destinationStop.stop.longName(),
                    null,
                    destinationStop.stop.latitude(),
                    destinationStop.stop.longitude(),
                    null,
                    null
            ));
        }

        return legs;
    }

    private List<RouteLeg> buildTransferLegs(String routeA, String routeB, CandidateStop originStop, CandidateStop destinationStop,
                                             String transferStopName,
                                             int walkOrigin, int waitA, int busA, int waitB, int busB, int walkDest) {
        List<RouteLeg> legs = new ArrayList<>();

        if (walkOrigin > 0) {
            legs.add(new RouteLeg("WALK", "Walk to " + originStop.stop.longName(), walkOrigin,
                    null, null, originStop.stop.longName(), null, null,
                    originStop.stop.latitude(), originStop.stop.longitude()));
        }

        legs.add(new RouteLeg("WAIT", "Wait for " + routeA, waitA,
                routeA, originStop.stop.longName(), originStop.stop.longName(),
                originStop.stop.latitude(), originStop.stop.longitude(),
                originStop.stop.latitude(), originStop.stop.longitude()));

        legs.add(new RouteLeg("BUS", routeA + " to transfer stop " + transferStopName, busA,
                routeA, originStop.stop.longName(), transferStopName,
                originStop.stop.latitude(), originStop.stop.longitude(),
                null, null));

        legs.add(new RouteLeg("WAIT", "Transfer and wait for " + routeB, waitB,
                routeB, transferStopName, transferStopName,
                null, null, null, null));

        legs.add(new RouteLeg("BUS", routeB + " from " + transferStopName + " to " + destinationStop.stop.longName(), busB,
                routeB, transferStopName, destinationStop.stop.longName(),
                null, null,
                destinationStop.stop.latitude(), destinationStop.stop.longitude()));

        if (walkDest > 0) {
            legs.add(new RouteLeg("WALK", "Walk to destination", walkDest,
                    null, destinationStop.stop.longName(), null,
                    destinationStop.stop.latitude(), destinationStop.stop.longitude(),
                    null, null));
        }

        return legs;
    }

    private boolean isBetter(PlanCandidate candidate, PlanCandidate currentBest) {
        if (candidate == null) return false;
        if (currentBest == null) return true;
        return candidate.totalMinutes < currentBest.totalMinutes;
    }

    private int estimateBusTravelMinutes(RoutePath path, int startIndex, int endIndex) {
        if (endIndex <= startIndex) return 0;

        double meters = 0;
        for (int i = startIndex; i < endIndex; i++) {
            RouteStop a = path.stops.get(i);
            RouteStop b = path.stops.get(i + 1);
            meters += haversine(a.stop.latitude(), a.stop.longitude(), b.stop.latitude(), b.stop.longitude());
        }

        double seconds = (meters / BUS_SPEED_MPS) * BUS_TIME_BUFFER;
        int stopsTraversed = Math.max(0, endIndex - startIndex);
        seconds += (double) stopsTraversed * DWELL_SECONDS_PER_STOP;

        return Math.max(1, (int) Math.ceil(seconds / 60.0));
    }

    private int estimateWaitMinutes(String stopName, String routeCode) {
        try {
            ShuttleServiceResult result = nusApiService.getShuttleService(stopName);
            if (result == null || result.shuttles() == null || result.shuttles().isEmpty()) {
                return DEFAULT_WAIT_MIN;
            }

            return result.shuttles().stream()
                    .filter(s -> equalsNormalized(s.name(), routeCode))
                    .findFirst()
                    .map(s -> parseEtaMinutes(s.arrivalTime()))
                    .orElse(DEFAULT_WAIT_MIN);
        } catch (Exception ignored) {
            return DEFAULT_WAIT_MIN;
        }
    }

    private int parseEtaMinutes(String etaText) {
        if (etaText == null || etaText.isBlank()) return DEFAULT_WAIT_MIN;

        String clean = etaText.trim().toLowerCase(Locale.ROOT);
        if (clean.contains("arr")) return 0;
        if (clean.contains("<1")) return 1;

        Matcher matcher = ETA_DIGIT_PATTERN.matcher(clean);
        if (matcher.find()) {
            return Math.min(120, Integer.parseInt(matcher.group(1)));
        }

        return DEFAULT_WAIT_MIN;
    }

    private Map<String, RoutePath> buildRoutePaths(List<BusStop> allStops) {
        Map<String, RoutePath> paths = new HashMap<>();

        List<ServiceDescription> routes = nusApiService.getServiceDescriptions();
        for (ServiceDescription route : routes) {
            String routeCode = route.route();
            if (routeCode == null || routeCode.isBlank()) continue;

            List<PickupPoint> pickupPoints = nusApiService.getPickupPoints(routeCode);
            if (pickupPoints == null || pickupPoints.isEmpty()) continue;

            List<PickupPoint> sorted = pickupPoints.stream()
                    .sorted(Comparator.comparingInt(PickupPoint::seq))
                    .toList();

            List<RouteStop> routeStops = new ArrayList<>();
            for (PickupPoint pp : sorted) {
                BusStop matched = matchBusStop(pp, allStops);
                routeStops.add(new RouteStop(routeCode, pp.seq(), matched));
            }

            if (routeStops.size() >= 2) {
                paths.put(routeCode, new RoutePath(routeCode, routeStops));
            }
        }

        return paths;
    }

    private BusStop matchBusStop(PickupPoint pickupPoint, List<BusStop> allStops) {
        String pickupLongName = normalize(pickupPoint.longName());

        Optional<BusStop> exact = allStops.stream()
                .filter(stop -> normalize(stop.longName()).equals(pickupLongName)
                        || normalize(stop.caption()).equals(pickupLongName)
                        || normalize(stop.shortName()).equals(pickupLongName))
                .findFirst();

        if (exact.isPresent()) return exact.get();

        // Fallback: closest stop by coordinate within 150m.
        Optional<BusStop> nearest = allStops.stream()
                .min(Comparator.comparingDouble(stop ->
                        haversine(pickupPoint.lat(), pickupPoint.lng(), stop.latitude(), stop.longitude())));

        if (nearest.isPresent()) {
            BusStop stop = nearest.get();
            double distance = haversine(pickupPoint.lat(), pickupPoint.lng(), stop.latitude(), stop.longitude());
            if (distance <= 150) {
                return stop;
            }
        }

        // Final fallback: synthetic stop from pickup point.
        return new BusStop(
                pickupPoint.pickupname(),
                pickupPoint.busstopcode(),
                pickupPoint.longName(),
                pickupPoint.shortName(),
                pickupPoint.lat(),
                pickupPoint.lng()
        );
    }

    private Location resolveLocation(String query) {
        if (query == null || query.isBlank()) {
            throw new IllegalArgumentException("Location query cannot be blank");
        }

        // 0) Try parsing as "lat,lng" coordinates.
        String[] parts = query.split(",");
        if (parts.length == 2) {
            try {
                double lat = Double.parseDouble(parts[0].trim());
                double lng = Double.parseDouble(parts[1].trim());
                return new Location("Current Location", lat, lng);
            } catch (NumberFormatException ignored) {
                // Not coordinates, continue with name resolution
            }
        }

        String normalizedQuery = normalize(query);

        // 1) Try bus stops first.
        List<BusStop> stops = nusApiService.getBusStops();
        Optional<BusStop> stopExact = stops.stream()
                .filter(stop -> equalsNormalized(stop.name(), normalizedQuery)
                        || equalsNormalized(stop.longName(), normalizedQuery)
                        || equalsNormalized(stop.caption(), normalizedQuery)
                        || equalsNormalized(stop.shortName(), normalizedQuery))
                .findFirst();
        if (stopExact.isPresent()) {
            BusStop s = stopExact.get();
            return new Location(s.longName(), s.latitude(), s.longitude());
        }

        // 2) Try buildings.
        List<Building> buildings = buildingService.getBuildings();
        Optional<Building> buildingExact = buildings.stream()
                .filter(b -> equalsNormalized(b.name(), normalizedQuery))
                .findFirst();
        if (buildingExact.isPresent()) {
            Building b = buildingExact.get();
            return new Location(b.name(), b.latitude(), b.longitude());
        }

        // 3) Partial-match fallback.
        Optional<BusStop> stopPartial = stops.stream()
                .filter(s -> normalize(s.longName()).contains(normalizedQuery)
                        || normalize(s.caption()).contains(normalizedQuery)
                        || normalize(s.name()).contains(normalizedQuery))
                .findFirst();
        if (stopPartial.isPresent()) {
            BusStop s = stopPartial.get();
            return new Location(s.longName(), s.latitude(), s.longitude());
        }

        Optional<Building> buildingPartial = buildings.stream()
                .filter(b -> normalize(b.name()).contains(normalizedQuery))
                .findFirst();
        if (buildingPartial.isPresent()) {
            Building b = buildingPartial.get();
            return new Location(b.name(), b.latitude(), b.longitude());
        }

        throw new IllegalArgumentException("Location not found: " + query);
    }

    private List<CandidateStop> candidateStops(double lat, double lng, List<BusStop> allStops, int radiusMeters, int limit) {
        return allStops.stream()
                .map(stop -> {
                    double distance = haversine(lat, lng, stop.latitude(), stop.longitude());
                    return new CandidateStop(stop, distance, walkingMinutes(distance));
                })
                .filter(c -> c.distanceMeters <= radiusMeters)
                .sorted(Comparator.comparingDouble(c -> c.distanceMeters))
                .limit(limit)
                .collect(Collectors.toList());
    }

    private int walkingMinutes(double distanceMeters) {
        if (distanceMeters <= 0) return 0;
        double seconds = (distanceMeters / WALK_SPEED_MPS) * WALK_TIME_BUFFER;
        return Math.max(1, (int) Math.ceil(seconds / 60.0));
    }

    private double haversine(double lat1, double lng1, double lat2, double lng2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.asin(Math.sqrt(a));
        return EARTH_RADIUS_METERS * c;
    }

    private String normalize(String value) {
        if (value == null) return "";
        return value.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
    }

    private boolean equalsNormalized(String a, String b) {
        return normalize(a).equals(normalize(b));
    }

    private record Location(String name, double latitude, double longitude) {}

    private record CandidateStop(BusStop stop, double distanceMeters, int walkMinutes) {}

    private record RouteStop(String routeCode, int seq, BusStop stop) {}

    private record RoutePath(String routeCode, List<RouteStop> stops) {
        int indexOfStop(String stopName) {
            String normalized = stopName == null ? "" : stopName.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
            for (int i = 0; i < stops.size(); i++) {
                String sName = stops.get(i).stop.name();
                String sNorm = sName == null ? "" : sName.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
                if (sNorm.equals(normalized)) return i;
            }
            return -1;
        }

        Set<String> commonStops(RoutePath other) {
            Set<String> mine = stops.stream().map(s -> s.stop.name()).collect(Collectors.toSet());
            Set<String> theirs = other.stops.stream().map(s -> s.stop.name()).collect(Collectors.toSet());
            mine.retainAll(theirs);
            return mine;
        }
    }

    private record PlanCandidate(int totalMinutes, int walkingMinutes, int waitingMinutes,
                                 int busMinutes, int transfers, List<RouteLeg> legs) {}
 }
