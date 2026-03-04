# NUS Motion Frontend Implementation Plan (AI Handoff)

This document is a **build-ready handoff** for an AI agent to implement the full Flutter frontend to replace the existing NUS Next Bus app UX.

---

## 1) Product scope and goals

Build a production-quality Flutter app with these major experiences:

1. **Map Discovery**
   - Live nearby stops
   - Live arrivals and capacity
   - Route overlays and active buses
2. **Search & Routing**
   - Search bus stops and buildings
   - Route plans (walk + wait + bus + transfer)
3. **Favorites**
   - Favorite lines/stops and recent trips
   - Local persistence only (no backend auth/db)
4. **Alerts & Status**
   - Announcements/ticker tapes
   - Weather at current location

Design source of truth: HTML screens under `design/screens/`.

---

## 2) Backend contracts (must match exactly)

Base URL (dev): `http://localhost:8080/api`

### Core transit endpoints
- `GET /stops`
- `GET /shuttles?stop={stopName}`
- `GET /active-buses?route={routeCode}`
- `GET /checkpoints?route={routeCode}`
- `GET /announcements`
- `GET /schedule?route={routeCode}`
- `GET /service-descriptions`
- `GET /pickup-points?route={routeCode}`
- `GET /ticker-tapes`

### Buildings
- `GET /buildings`
- `GET /buildings/{name}/nearest-stop`

### Newly implemented routing/location/weather
- `GET /nearby-stops?lat={lat}&lng={lng}&radius={meters}&limit={n}`
- `GET /route?from={query}&to={query}`
- `GET /weather?lat={lat}&lng={lng}`

### Experimental passthroughs (handle gracefully)
- `GET /publicity` *(upstream may intermittently 500)*
- `GET /bus-location?route={routeCode}` *(upstream often 500)*

---

## 3) Required screens and behavior

## 3.1 Map Discovery screen

### UI blocks
- Full-screen map
- Top search bar (destination/stop/line)
- Draggable bottom sheet with nearby stops
- Stop cards with:
  - stop name
  - next arrivals
  - bus line badges
  - occupancy/crowd indicator
- Bottom tab navigation

### Data flow
1. Get location (permission flow)
2. Call `/nearby-stops`
3. For each visible stop, call `/shuttles?stop=...`
4. When a route is selected, overlay `/checkpoints?route=...`
5. Optional moving bus markers from `/active-buses?route=...`

### Polling policy
- nearby stops: refresh on location move or manual refresh
- shuttles: every 10s when screen active
- active buses: every 10–15s when route overlay active

---

## 3.2 Search & Routing screen

### UI blocks
- From (default current location) + To input
- Autocomplete suggestions from both `/stops` and `/buildings`
- Route result card(s) with legs
  - walk leg
  - wait leg
  - bus leg
  - transfer when present
- Total time and transfer count as top-level summary

### Data flow
1. Cache `/stops` and `/buildings` for autocomplete
2. On submit: call `/route?from=...&to=...`
3. Render `RoutePlanResult`:
   - `totalMinutes`, `walkingMinutes`, `waitingMinutes`, `busMinutes`, `transfers`
   - ordered `legs`

### Edge states
- 404 location not found → show inline validation + suggestion chips
- 422 no route possible → friendly empty-state card

---

## 3.3 Favorites screen

### Scope (local-only)
- Favorite routes (line codes)
- Favorite stops
- Recent searches
- Recent trips

### Storage
Use local persistence only:
- Recommended: `Hive` (or `shared_preferences` for lightweight lists)
- Keys:
  - `favorite_routes`
  - `favorite_stops`
  - `recent_searches`
  - `recent_trips`

### UX
- Swipe-to-delete for saved stops
- Tap favorite line to pre-filter map/search
- Show quick live ETA for saved stops via `/shuttles`

---

## 3.4 Alerts & Status screen

### UI blocks
- Tabs: All / Service / Weather / Personal
- Announcements and ticker tape cards
- Weather card for current location

### Data flow
- `/announcements` + `/ticker-tapes` every 30s
- `/weather?lat&lng` every 5 minutes

### Notes
- Build weather condition mapping from WMO `weatherCode`
- If weather API fails, keep last good value and show “stale” badge

---

## 4) Flutter architecture

Use a clear feature-first architecture.

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
  core/
    network/
    errors/
    utils/
    widgets/
  features/
    map_discovery/
    search_routing/
    favorites/
    alerts/
  data/
    models/
    repositories/
    services/
  state/
    providers/
```

### Recommended stack
- State: Riverpod
- Networking: Dio
- Routing: go_router
- Maps: flutter_map (Leaflet) or google_maps_flutter
- Local storage: Hive

---

## 5) Frontend models to define

At minimum create Dart models for:
- `BusStop`
- `Shuttle`, `ShuttleServiceResult`
- `ActiveBus`
- `CheckPoint`
- `Announcement`
- `RouteSchedule`
- `ServiceDescription`
- `PickupPoint`
- `TickerTape`
- `Building`
- `NearestStopResult`
- `NearbyStopResult`
- `RouteLeg`
- `RoutePlanResult`
- `WeatherSnapshot`

Use `json_serializable` and exact JSON key mapping.

---

## 6) API client requirements

- Centralized API service with request timeout and retries (for transient failures)
- Graceful handling for known unstable upstream-backed endpoints:
  - `/publicity`
  - `/bus-location`
- Error envelope mapping for backend 404/422/502 responses

---

## 7) Non-functional requirements

- Smooth 60fps on map interactions
- Avoid over-fetching:
  - dedupe concurrent stop ETA calls
  - cache static data (`/stops`, `/buildings`, `/service-descriptions`)
- Background refresh only when relevant screen visible
- All list screens must have loading, error, and empty states

---

## 8) Testing requirements

## 8.1 Unit tests
- ETA formatter
- route leg rendering helpers
- favorites local repository
- weather code → icon/text mapper

## 8.2 Widget tests
- Map bottom sheet stop card rendering
- Route card with transfer legs
- Alerts list rendering with error and empty states

## 8.3 Integration tests
- search → route generation flow
- map stop tap → arrivals shown
- save favorite stop → appears in favorites and survives restart

---

## 9) Milestones and implementation order

### Milestone 1 — Foundation
- App shell, theme, router, network layer, error handling, local storage wiring

### Milestone 2 — Data + Map Discovery MVP
- `/stops`, `/nearby-stops`, `/shuttles`, map markers, bottom sheet

### Milestone 3 — Search + Routing
- autocomplete + `/route` rendering + route leg timeline

### Milestone 4 — Favorites
- save/remove lines and stops, recent search/trip history

### Milestone 5 — Alerts + Weather
- `/announcements`, `/ticker-tapes`, `/weather`

### Milestone 6 — Polish + QA
- animations, skeleton loaders, retry UX, integration tests, performance tuning

---

## 10) Acceptance criteria (must pass)

- User can open app and see nearby stops with ETAs
- User can search **either stop or building** and get a route plan
- User can save favorites locally and retrieve them after restart
- Alerts + weather display with graceful failure behavior
- No blocking crashes on network failures
- Core integration tests pass

---

## 11) Important implementation notes for the AI agent

1. Keep API contracts aligned with backend DTO field names exactly.
2. Use URL encoding for building names in paths.
3. Treat `/publicity` and `/bus-location` as optional/unstable data sources.
4. Favor deterministic polling intervals and cancellation when screens are hidden.
5. Prioritize working end-to-end flows over perfect visual polish in early milestones.

---

## 12) Immediate first tasks for implementation agent

1. Scaffold architecture + dependencies.
2. Implement API services and typed models.
3. Build Map Discovery with nearby + shuttles.
4. Build Search & Routing with `/route` integration.
5. Add local favorites persistence.
6. Add alerts + weather.
7. Add tests and harden error handling.
