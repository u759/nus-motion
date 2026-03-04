# NUS Motion Frontend — Specs & Architecture (AI Handoff)

This document is the companion to `FRONTEND_IMPLEMENTATION_PLAN.md`.
It defines **API contracts, architecture decisions, feature mapping, and guardrails** so an AI coding agent can implement the frontend end-to-end with minimal ambiguity.

---

## 1) Goals and constraints

### Goals
- Replace existing NUS Next Bus UX with a modern Flutter app.
- Support 4 design surfaces:
  - Map Discovery
  - Search & Routing
  - Favorites
  - Alerts & Status
- Use backend APIs as system-of-record for transit/routing/weather data.

### Constraints
- No backend auth/database for user preferences (favorites/recent/reminders are local only).
- Must gracefully handle unstable upstream-backed endpoints.
- Mobile-first UX and responsive behavior.
- Reliable loading/error/empty states for all async views.

---

## 2) API contract spec (frontend-facing)

Base URL (dev): `http://localhost:8080/api`

## 2.1 Transit core

| Endpoint | Method | Params | Success | Common errors |
|---|---|---|---|---|
| `/stops` | GET | — | `List<BusStop>` | 5xx |
| `/shuttles` | GET | `stop` | `ShuttleServiceResult` | 5xx |
| `/active-buses` | GET | `route` | `List<ActiveBus>` | 5xx |
| `/checkpoints` | GET | `route` | `List<CheckPoint>` | 5xx |
| `/schedule` | GET | `route` | `List<RouteSchedule>` | 5xx |
| `/service-descriptions` | GET | — | `List<ServiceDescription>` | 5xx |
| `/pickup-points` | GET | `route` | `List<PickupPoint>` | 5xx |
| `/announcements` | GET | — | `List<Announcement>` | 5xx |
| `/ticker-tapes` | GET | — | `List<TickerTape>` | 5xx |

## 2.2 Buildings, routing, geolocation, weather

| Endpoint | Method | Params | Success | Common errors |
|---|---|---|---|---|
| `/buildings` | GET | — | `List<Building>` | 5xx |
| `/buildings/{name}/nearest-stop` | GET | path `name` (URL-encoded) | `NearestStopResult` | 404 |
| `/nearby-stops` | GET | `lat,lng,radius,limit` | `List<NearbyStopResult>` | 4xx/5xx |
| `/route` | GET | `from,to` | `RoutePlanResult` | 404 (not found), 422 (no route) |
| `/weather` | GET | `lat,lng` | `WeatherSnapshot` | 5xx |

## 2.3 Experimental/unstable passthroughs

| Endpoint | Method | Notes |
|---|---|---|
| `/publicity` | GET | Upstream is intermittent (can return 500) |
| `/bus-location` | GET | Frequently upstream 500 |

### Error response shape
Treat backend error body as:

```json
{ "error": "human-readable message" }
```

Some endpoints additionally include metadata (e.g., `upstreamStatus`).

---

## 3) Feature mapping (design → APIs)

### Map Discovery (`design/screens/map_discovery.html`)
- Nearby stops list: `/nearby-stops`
- Stop arrivals + capacity: `/shuttles?stop=...`
- Route polylines: `/checkpoints?route=...`
- Active bus markers: `/active-buses?route=...`

### Search & Routing (`design/screens/search_routing.html`)
- Suggestions: `/stops` + `/buildings`
- Route compute: `/route?from=...&to=...`
- Building fallback: `/buildings/{name}/nearest-stop`

### Favorites (`design/screens/favorites.html`)
- Local-only persistence (Hive/shared_preferences)
- Optional live ETA for saved stops via `/shuttles`

### Alerts & Status (`design/screens/alerts_status.html`)
- Service alerts: `/announcements`, `/ticker-tapes`
- Weather card: `/weather?lat=...&lng=...`

---

## 4) Architecture decisions and rationale

### State management
- **Riverpod** (recommended)
  - Async providers for API calls
  - family providers for parameterized fetches (`shuttles(stopName)`)
  - easy testability and dependency injection

### Networking
- **Dio**
  - centralized interceptors
  - timeout/retry policy
  - standardized error mapping

### Navigation
- **go_router**
  - explicit route graph
  - easy deep-link compatibility

### Storage
- **Hive** (preferred) for local favorites/recents/reminders

### Suggested Flutter module layout

```text
lib/
  app/                # router, theme, app bootstrap
  core/               # network, errors, common widgets/utils
  data/               # api services + dto models + repositories
  features/
    map_discovery/
    search_routing/
    favorites/
    alerts/
  state/              # global providers
```

---

## 5) Design and code references

### Design HTML references
- `design/screens/map_discovery.html`
- `design/screens/search_routing.html`
- `design/screens/favorites.html`
- `design/screens/alerts_status.html`

### Backend API/controller references
- `backend/src/main/java/com/nusmotion/backend/controller/BusController.java`
- `backend/src/main/java/com/nusmotion/backend/controller/BuildingController.java`

### Existing implementation plan reference
- `frontend/FRONTEND_IMPLEMENTATION_PLAN.md`

---

## 6) Implementation guardrails for the AI coding agent

1. **Model keys must match backend JSON exactly** (including case).
2. **URL-encode building names** in path endpoints.
3. Polling should be lifecycle-aware (pause when screen inactive).
4. `/publicity` and `/bus-location` are optional data sources; never crash UI if they fail.
5. Cache static lists (`/stops`, `/buildings`, `/service-descriptions`) aggressively.
6. Always provide loading, error, and empty states for each async component.
7. Local data is source-of-truth for favorites/recent/reminders (no backend writes).

---

## 7) Definition of Done (frontend)

- [ ] Map Discovery loads and shows nearby stops + arrivals + route overlays
- [ ] Search supports both stops and buildings and returns route plans
- [ ] Route card renders legs (walk/wait/bus/transfer) with total time
- [ ] Favorites persist after app restart
- [ ] Alerts screen shows announcements/ticker/weather with graceful fallback
- [ ] All screens handle network failure safely
- [ ] `flutter analyze` clean and core widget/integration tests pass

---

## 8) Recommended execution order

1. App shell + router + theme + network layer
2. Typed models + API services
3. Map Discovery (nearby + shuttles)
4. Search & Routing
5. Favorites local persistence
6. Alerts & Weather
7. Testing, polish, and performance

---

## 9) Notes on upstream behavior validation

Live curl checks (using configured auth header) showed:
- `/BusLocation` is consistently 500 upstream.
- `/publicity` can be intermittent (seen both success and 500).

Frontend should treat both as **non-critical optional enhancements**.
