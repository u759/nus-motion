# NUS Motion — Build Guide

> A hands-on Spring Boot + Flutter project that replaces the NUS NextBus app.
> **Goal:** Learn Spring Boot patterns (DI, caching, REST, WebClient) by building a real proxy that you and other students will actually use.

---

## What's Already Done For You

| Item | Status |
|---|---|
| Spring Boot 4.0.3 project with Java 21 | ✅ |
| Dependencies (web, cache, caffeine, webflux, devtools) | ✅ |
| `application.properties` with all API keys & config | ✅ |
| `NusApiProperties` — type-safe config binding | ✅ |
| `CacheConfig` — Caffeine cache with 10s TTL | ✅ |
| `WebClientConfig` — pre-authenticated HTTP client | ✅ |
| DTOs: `BusStop`, `Shuttle`, `ActiveBus`, `Wrappers` | ✅ |
| `NusApiService` — 3 core methods with `@Cacheable` | ✅ |
| `BusController` — 3 REST endpoints | ✅ |
| OpenAPI spec (`docs/nus-nextbus-openapi.yaml`) | ✅ |
| UI designs (`design/screens/*.html` + `*.png`) | ✅ |

---

## Architecture at a Glance

```
Flutter App  ──HTTP──▶  Spring Boot Proxy  ──HTTP──▶  NUS NextBus API
                         (your backend)                (upstream)
                              │
                        Caffeine Cache
                        (10s TTL for live data)
                        (5min TTL for static data)
```

**Why a proxy?** The NUS API requires a secret auth header. You can't put that in a mobile app — anyone could decompile it. The proxy holds the secret server-side and also caches responses so 500 students hitting refresh don't hammer the upstream API.

---

## Phase 1: Backend (Spring Boot)

### Step 1 — Run It

```bash
cd backend
./mvnw spring-boot:run
```

Open http://localhost:8080/api/stops in your browser. You should see JSON bus stop data.

### Step 2 — Understand The Flow

Trace a single request through the code:

1. **Browser** hits `GET /api/stops`
2. **`BusController.getStops()`** receives it (because of `@GetMapping("/stops")`)
3. Controller calls **`NusApiService.getBusStops()`**
4. Spring's cache proxy checks: is there a cached result for `"busStops"`?
   - **Cache HIT** → return cached data, method body never runs
   - **Cache MISS** → execute method body, store result, return it
5. Inside the method body, **WebClient** makes an HTTP GET to `https://nnextbus.nus.edu.sg/BusStops` with the auth header
6. Jackson **deserializes** the JSON into `BusStopsResponse` → `BusStopsResult` → `List<BusStop>`
7. The `List<BusStop>` flows back through the controller and Spring serializes it to JSON for the browser

**Experiment:** Hit `/api/stops` twice quickly. Check the terminal logs — you'll see `"Cache MISS"` only on the first call.

### Step 3 — Try the Live Endpoints

```
GET http://localhost:8080/api/stops
GET http://localhost:8080/api/shuttles?stop=UTown
GET http://localhost:8080/api/active-buses?route=A1
```

Use your browser, `curl`, or the VS Code REST Client extension.

### Step 4 — Your Coding Tasks

These are designed so Copilot autocomplete does most of the typing, but **you** understand every line.

#### Task A: Add `/api/checkpoints?route=A1`

This endpoint returns the GPS polyline for drawing a bus route on the map.

1. **Create the DTO** — `src/.../dto/CheckPoint.java`
   - Fields: `pointId` (String), `latitude` (double), `longitude` (double), `routeid` (int)
   - Use `@JsonProperty` to map from upstream PascalCase

2. **Add the wrapper** in `Wrappers.java`
   - `CheckPointResponse` wrapping `CheckPointResult` wrapping `List<CheckPoint>`

3. **Add service method** in `NusApiService.java`
   - `@Cacheable(value = "checkpoints", key = "#routeCode")`
   - URI: `/CheckPoint?route_code={routeCode}`

4. **Add controller endpoint** in `BusController.java`
   - `@GetMapping("/checkpoints")` with `@RequestParam("route")`

5. **Test:** `curl http://localhost:8080/api/checkpoints?route=A1`

#### Task B: Add `/api/announcements`

Service disruption alerts. No parameters needed.

1. DTO: `Announcement.java` — fields: `id`, `text`, `status`, `priority`, `affectedServiceIds`
2. Wrapper in `Wrappers.java`
3. Service method with `@Cacheable("announcements")`
4. Controller endpoint

#### Task C: Add `/api/schedule?route=A1`

Operating hours for a route (first/last bus by day type).

1. DTO: `RouteSchedule.java` — fields: `dayType`, `firstTime`, `lastTime`, `scheduleType`
2. Wrapper, service, controller — same pattern

#### Task D: Tune Cache TTLs

The current config uses the same 10s TTL for everything. That's wasteful for data that barely changes.

In `CacheConfig.java`, register named caches:
```java
manager.registerCustomCache("busStops",
    Caffeine.newBuilder()
        .expireAfterWrite(Duration.ofMinutes(5))
        .maximumSize(1)
        .build());

manager.registerCustomCache("checkpoints",
    Caffeine.newBuilder()
        .expireAfterWrite(Duration.ofMinutes(10))
        .maximumSize(20)
        .build());
```

**Think about:** Why is `maximumSize(1)` fine for `busStops` but not for `shuttleService`?
Answer: `busStops` has no parameters — there's only one possible cached value. `shuttleService` is keyed by stop name, so each stop gets its own cache entry.

---

## Key Spring Boot Concepts You'll Learn

### 1. Dependency Injection (DI)
Look at `BusController`:
```java
public BusController(NusApiService nusApiService) {
    this.nusApiService = nusApiService;
}
```
You never write `new NusApiService(...)`. Spring creates the instance, wires up its dependencies (WebClient), and injects it into the controller. This is **Inversion of Control**.

### 2. @ConfigurationProperties
Instead of scattered `@Value` annotations:
```java
@ConfigurationProperties(prefix = "nus.api")
public record NusApiProperties(String baseUrl, String authHeader, String userAgent) {}
```
One record, one prefix, type-safe. If you typo a property name, the app won't start.

### 3. @Cacheable
```java
@Cacheable(value = "shuttleService", key = "#busstopname")
public ShuttleServiceResult getShuttleService(String busstopname) { ... }
```
Spring generates a proxy around your service. Before your method runs, the proxy checks the cache. This is **AOP (Aspect-Oriented Programming)** in action.

### 4. WebClient
Modern, fluent HTTP client:
```java
nusApiClient.get()
    .uri(b -> b.path("/ShuttleService").queryParam("busstopname", stop).build())
    .retrieve()
    .bodyToMono(ShuttleServiceResponse.class)
    .block();
```

### 5. Records as DTOs
Java records give you immutable value objects with minimal boilerplate — perfect for JSON mapping.

---

## Phase 2: Frontend (Flutter) — Coming Next

The UI designs are in `design/screens/`:
- **Map Discovery** — full-screen map with live bus markers + bottom drawer showing nearby stops
- **Search & Routing** — search bar + route suggestions + estimated walk times
- **Favorites** — saved stops with live arrival times
- **Alerts & Status** — service announcements + route status cards

Tech stack: Flutter + Riverpod + Google Maps SDK. We'll wire it to `http://localhost:8080/api/*`.

---

## File Map

```
backend/
├── src/main/java/com/nusmotion/backend/
│   ├── BackendApplication.java          ← entry point
│   ├── config/
│   │   ├── NusApiProperties.java        ← reads nus.api.* from properties
│   │   ├── CacheConfig.java             ← Caffeine cache setup
│   │   └── WebClientConfig.java         ← pre-authenticated HTTP client
│   ├── dto/
│   │   ├── BusStop.java                 ← bus stop data model
│   │   ├── Shuttle.java                 ← arrival time data model
│   │   ├── ActiveBus.java               ← real-time GPS data model
│   │   └── Wrappers.java               ← JSON wrapper records
│   ├── service/
│   │   └── NusApiService.java           ← business logic + caching
│   └── controller/
│       └── BusController.java           ← REST endpoints
├── src/main/resources/
│   └── application.properties           ← all configuration
docs/
│   └── nus-nextbus-openapi.yaml         ← upstream API spec
design/
│   └── screens/                         ← Stitch UI mockups (HTML + PNG)
```

---

## Quick Reference: Upstream API

| Your Endpoint | Upstream | Cache TTL | Notes |
|---|---|---|---|
| `GET /api/stops` | `/BusStops` | 5 min | Static data |
| `GET /api/shuttles?stop=X` | `/ShuttleService?busstopname=X` | 10 sec | Live arrivals |
| `GET /api/active-buses?route=X` | `/ActiveBus?route_code=X` | 10 sec | Live GPS |
| `GET /api/checkpoints?route=X` | `/CheckPoint?route_code=X` | 10 min | Static polyline |
| `GET /api/announcements` | `/Announcements` | 30 sec | Semi-live |
| `GET /api/schedule?route=X` | `/RouteMinMaxTime?route_code=X` | 1 hour | Rarely changes |
