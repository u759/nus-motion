# NUS Motion Frontend V2 — Complete Rebuild Plan

> **Purpose:** Build-ready specification for an AI agent to implement the entire Flutter frontend from scratch, aligned with the new Stitch design screens, backend API contracts, and Flutter best practices.

---

## 1. Design System (Source of Truth)

### 1.1 Design References

| Screen | HTML | Screenshot | Purpose |
|--------|------|-----------|---------|
| Route Planner (v2) | `design/screens/route_planner_v2.html` | `route_planner_v2.png` | Route result detail view with timeline steps |
| Route Planner (v3) | `design/screens/route_planner_v3.html` | `route_planner_v3.png` | Main search + map view with bottom sheet route cards |
| Active Transit (v1) | `design/screens/active_transit_v1.html` | `active_transit_v1.png` | Live trip tracking with timeline + progress |
| Service Alerts (Light) | `design/screens/service_alerts_light.html` | `service_alerts_light.png` | Alerts list with tabs, current + past sections |

### 1.2 Brand & Color Palette

From the Stitch HTML designs, the app uses a **light theme** with these colors:

```
Primary:           #135BEC (blue)
Background Light:  #F8FAFC (slate-50) or #FFFFFF (white)
Background Dark:   #0F172A (slate-900, for potential dark mode)
Surface:           #FFFFFF (white cards)
Surface Muted:     #F8FAFC (slate-50, section backgrounds)
Border:            #E2E8F0 (slate-200)
Border Light:      #F1F5F9 (slate-100)
Text Primary:      #0F172A (slate-900)
Text Secondary:    #64748B (slate-500)
Text Muted:        #94A3B8 (slate-400)
Success/On-time:   #059669 (emerald-600)
Warning:           #D97706 (amber-600)
Error/Danger:      #DC2626 (red-600)
Orange Accent:     #EA580C (orange-600)
Info:              #135BEC (primary blue)
```

### 1.3 Typography

- **Display Font:** Plus Jakarta Sans (headings, bold labels)
- **Body Font:** Inter (body text, descriptions)
- **Fallback:** system sans-serif
- **Weights:** 400 (regular), 500 (medium), 600 (semibold), 700 (bold), 800 (extrabold)

### 1.4 Design Tokens

```
Spacing:    4, 8, 12, 16, 20, 24, 32 (px)
Radius:     4 (sm), 8 (md/default), 12 (lg/xl), 16 (2xl), 24 (3xl), 9999 (full)
Shadows:    shadow-sm (cards), shadow-md (floating elements), shadow-lg (bottom sheet)
```

### 1.5 Icon System

- **Material Symbols Outlined** (Google Fonts, weight 400)
- Optionally **filled** variant via `font-variation-settings: 'FILL' 1` for active nav items
- Key icons used: `arrow_back`, `tune`, `directions_walk`, `directions_bus`, `subway`, `location_on`, `my_location`, `navigation`, `sensors`, `warning`, `info`, `check_circle`, `settings_suggest`, `search`, `swap_vert`, `layers`, `near_me`, `flag`, `bookmark`, `map`, `route`, `explore`, `person`, `account_circle`, `notifications`, `home`

---

## 2. Architecture

### 2.1 Directory Structure

```
lib/
  main.dart                         # App entry, ProviderScope, Hive init
  app/
    app.dart                        # MaterialApp.router wrapper
    router.dart                     # GoRouter with StatefulShellRoute
    theme.dart                      # Light theme (+ optional dark)
  core/
    constants/
      api_constants.dart            # Base URL, timeouts
      app_constants.dart            # Polling intervals, defaults
    network/
      api_client.dart               # Dio client with interceptors
      api_exception.dart            # Typed error wrapper
    utils/
      eta_formatter.dart            # Parse "Arr", "<1 min", "2 mins" etc
      weather_mapper.dart           # WMO code → icon + description
      distance_formatter.dart       # Meters → "150m" or "1.2 km"
    widgets/
      loading_shimmer.dart          # Generic shimmer placeholder
      error_card.dart               # Retry-able error state
      empty_state.dart              # Friendly "nothing here" state
      route_badge.dart              # Colored route code chip
  data/
    models/
      bus_stop.dart                 # BusStop
      shuttle.dart                  # Shuttle, ShuttleServiceResult
      active_bus.dart               # ActiveBus, LoadInfo
      checkpoint.dart               # CheckPoint
      announcement.dart             # Announcement
      route_schedule.dart           # RouteSchedule
      service_description.dart      # ServiceDescription
      pickup_point.dart             # PickupPoint
      ticker_tape.dart              # TickerTape
      building.dart                 # Building
      nearby_stop_result.dart       # NearbyStopResult
      nearest_stop_result.dart      # NearestStopResult
      route_leg.dart                # RouteLeg
      route_plan_result.dart        # RoutePlanResult
      weather_snapshot.dart         # WeatherSnapshot
    services/
      transit_service.dart          # All /api/* calls via Dio
    repositories/
      favorites_repository.dart     # Hive-backed favorites/recents
  features/
    map_discovery/
      map_discovery_screen.dart     # Full-screen map + bottom sheet
      widgets/
        nearby_stop_card.dart       # Stop card in bottom sheet
        shuttle_arrival_tile.dart   # Individual shuttle ETA row
        capacity_indicator.dart     # Occupancy bar/badge
    search_routing/
      search_routing_screen.dart    # Route Planner (v3) — search + map + bottom sheet
      route_detail_screen.dart      # Route Planner (v2) — expanded route detail
      widgets/
        from_to_input.dart          # Origin/destination input card
        route_summary_card.dart     # Compact route card (total time + badges)
        route_detail_card.dart      # Expanded card with step timeline
        route_step_tile.dart        # Single step (walk/bus/arrive) in timeline
        suggestion_tile.dart        # Autocomplete suggestion row
    active_transit/
      active_transit_screen.dart    # Active Transit (v1) — live trip tracking
      widgets/
        trip_status_card.dart       # "Get off in 3 stops" + progress bar
        stops_timeline.dart         # Vertical timeline of passed/upcoming stops
    favorites/
      favorites_screen.dart         # Saved stops + routes
      widgets/
        saved_stop_card.dart        # Favorited stop with live ETA
        favorite_route_card.dart    # Favorited route summary
    alerts/
      alerts_screen.dart            # Service Alerts (Light) — tabs + alert cards
      widgets/
        alert_card.dart             # Alert item (icon + title + time + body)
        weather_card.dart           # Current weather conditions
  state/
    providers.dart                  # All Riverpod providers
```

### 2.2 Technology Stack

| Concern | Package | Version |
|---------|---------|---------|
| State Management |  _riverpod | ^2.6.1 |
| Networking | dio | ^5.8.0+1 |
| Navigation | go_router | ^15.1.2 |
| Maps | google_maps_flutter | ^2.12.1 |
| Local Storage | hive_flutter | ^1.1.0 |
| Location | geolocator | ^13.0.2 |
| Date/Time | intl | ^0.20.2 |
| Image Cache | cached_network_image | ^3.4.1 |
| Loading States | shimmer | ^3.0.0 |

### 2.3 State Management Strategy (Riverpod)

```dart
// -- Singletons --
final apiClientProvider = Provider<ApiClient>(...);
final transitServiceProvider = Provider<TransitService>(...);
final favoritesRepositoryProvider = Provider<FavoritesRepository>(...);

// -- Location Stream --
final positionStreamProvider = StreamProvider<Position>(...);

// -- Cached static data (FutureProvider) --
final stopsProvider = FutureProvider<List<BusStop>>(...);
final buildingsProvider = FutureProvider<List<Building>>(...);
final serviceDescriptionsProvider = FutureProvider<List<ServiceDescription>>(...);

// -- Parameterized queries (FutureProvider.family) --
final shuttlesProvider = FutureProvider.family<ShuttleServiceResult, String>(...);  // by stopName
final activeBusesProvider = FutureProvider.family<List<ActiveBus>, String>(...);    // by routeCode
final checkpointsProvider = FutureProvider.family<List<CheckPoint>, String>(...);   // by routeCode
final pickupPointsProvider = FutureProvider.family<List<PickupPoint>, String>(...); // by routeCode
final scheduleProvider = FutureProvider.family<List<RouteSchedule>, String>(...);   // by routeCode
final nearbyStopsProvider = FutureProvider.family<List<NearbyStopResult>, ({double lat, double lng})>(...);
final routeProvider = FutureProvider.family<RoutePlanResult, ({String from, String to})>(...);
final weatherProvider = FutureProvider.family<WeatherSnapshot, ({double lat, double lng})>(...);

// -- Non-parameterized feeds --
final announcementsProvider = FutureProvider<List<Announcement>>(...);
final tickerTapesProvider = FutureProvider<List<TickerTape>>(...);

// -- Local persistence (StateNotifier) --
final favoriteStopsProvider = StateNotifierProvider<FavoriteStopsNotifier, List<String>>(...);
final favoriteRoutesProvider = StateNotifierProvider<FavoriteRoutesNotifier, List<String>>(...);
final recentSearchesProvider = StateNotifierProvider<RecentSearchesNotifier, List<String>>(...);
```

---

## 3. Backend API Contract

### 3.1 Base URL
```
http://localhost:8080/api
```

### 3.2 Endpoints

| Endpoint | Params | Response Type | Poll Rate |
|----------|--------|--------------|-----------|
| `GET /stops` | — | `List<BusStop>` | Cache 5 min |
| `GET /shuttles` | `stop=STRING` | `ShuttleServiceResult` (contains `List<Shuttle>`) | 10s |
| `GET /active-buses` | `route=STRING` | `List<ActiveBus>` | 10s |
| `GET /checkpoints` | `route=STRING` | `List<CheckPoint>` | Static |
| `GET /announcements` | — | `List<Announcement>` | 30s |
| `GET /schedule` | `route=STRING` | `List<RouteSchedule>` | Static |
| `GET /service-descriptions` | — | `List<ServiceDescription>` | Static |
| `GET /pickup-points` | `route=STRING` | `List<PickupPoint>` | Static |
| `GET /ticker-tapes` | — | `List<TickerTape>` | 30s |
| `GET /buildings` | — | `List<Building>` | Cache 1hr |
| `GET /buildings/{name}/nearest-stop` | Path: `name` (URL-encoded) | `NearestStopResult` | On-demand |
| `GET /nearby-stops` | `lat`, `lng`, `radius` (def 800), `limit` (def 5) | `List<NearbyStopResult>` | 20s |
| `GET /route` | `from=STRING`, `to=STRING` | `RoutePlanResult` | On-demand |
| `GET /weather` | `lat`, `lng` | `WeatherSnapshot` | 5 min |
| `GET /publicity` | — | `String` (JSON) | **Experimental** |
| `GET /bus-location` | `route`, `stop` (optional) | `String` (JSON) | **Experimental** |

### 3.3 Data Models (Must Match Backend JSON Exactly)

```dart
// BusStop
class BusStop {
  final String caption;
  final String name;
  final String longName;   // JSON: "LongName"
  final String shortName;  // JSON: "ShortName"
  final double latitude;
  final double longitude;
}

// Shuttle
class Shuttle {
  final String name;
  final String arrivalTime;
  final String arrivalTimeVehPlate;     // JSON: "arrivalTime_veh_plate"
  final String nextArrivalTime;
  final String nextArrivalTimeVehPlate; // JSON: "nextArrivalTime_veh_plate"
  final String passengers;
  final String nextPassengers;
}

// ShuttleServiceResult
class ShuttleServiceResult {
  final String? caption;
  final List<Shuttle> shuttles;
}

// ActiveBus
class ActiveBus {
  final String vehPlate;   // JSON: "vehplate" or "veh_plate"
  final double lat;
  final double lng;
  final int speed;
  final double direction;
  final LoadInfo? loadInfo;
}

class LoadInfo {
  final double occupancy;
  final String crowdLevel;
  final int capacity;
  final int ridership;
}

// CheckPoint
class CheckPoint {
  final String pointId;    // JSON: "PointID"
  final double latitude;
  final double longitude;
  final int routeid;
}

// Announcement
class Announcement {
  final String id;                  // JSON: "ID"
  final String text;                // JSON: "Text"
  final String status;              // JSON: "Status"
  final String priority;            // JSON: "Priority"
  final String affectedServiceIds;  // JSON: "Affected_Service_Ids"
}

// RouteSchedule
class RouteSchedule {
  final String dayType;       // JSON: "DayType"
  final String firstTime;     // JSON: "FirstTime"
  final String lastTime;      // JSON: "LastTime"
  final String scheduleType;  // JSON: "ScheduleType"
}

// ServiceDescription
class ServiceDescription {
  final String route;             // JSON: "Route"
  final String routeDescription;  // JSON: "RouteDescription"
  final String routeLongName;     // JSON: "RouteLongName"
}

// PickupPoint
class PickupPoint {
  final int seq;
  final String busstopcode;
  final String longName;    // JSON: "LongName"
  final String shortName;   // JSON: "ShortName"
  final double lat;
  final double lng;
  final String pickupname;
  final int routeid;
}

// TickerTape
class TickerTape {
  final double? accidentLatitude;   // JSON: "Accident_Latitude"
  final double? accidentLongitude;  // JSON: "Accident_Longitude"
  final String affectedServiceIds;  // JSON: "Affected_Service_Ids"
  final String id;                  // JSON: "ID"
  final String message;             // JSON: "Message"
  final String priority;            // JSON: "Priority"
  final String status;              // JSON: "Status"
}

// Building
class Building {
  final String elementId;
  final String name;
  final String address;
  final String postal;
  final double latitude;
  final double longitude;
}

// NearbyStopResult
class NearbyStopResult {
  final String stopName;
  final String stopDisplayName;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final int walkingMinutes;
}

// NearestStopResult
class NearestStopResult {
  final String buildingName;
  final double buildingLatitude;
  final double buildingLongitude;
  final String busStopName;
  final String busStopDisplayName;
  final double busStopLatitude;
  final double busStopLongitude;
  final double distanceMeters;
}

// RoutePlanResult
class RoutePlanResult {
  final String from;
  final String to;
  final int totalMinutes;
  final int walkingMinutes;
  final int waitingMinutes;
  final int busMinutes;
  final int transfers;
  final List<RouteLeg> legs;
}

// RouteLeg
class RouteLeg {
  final String mode;        // "WALK", "WAIT", "BUS"
  final String instruction;
  final int? minutes;
  final String? routeCode;
  final String? fromStop;
  final String? toStop;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
}

// WeatherSnapshot
class WeatherSnapshot {
  final String timezone;
  final String time;
  final double temperatureCelsius;
  final int weatherCode;
  final double precipitationMm;
  final double windSpeedKph;
  final int? nextHourPrecipitationProbability;
}
```

---

## 4. Screen Specifications

### 4.1 Map Discovery (Tab 1: "Explore")

**Based on:** Route Planner v3 map background pattern + existing map_discovery requirements.

**Layout:**
- Full-screen Google Map with current location marker
- Floating top search bar (tap opens Search/Routing screen)
- Map controls on right side (my location button)
- Draggable bottom sheet with:
  - Drag handle
  - "Nearby Stops" title
  - List of nearby stop cards

**Nearby Stop Card (per stop):**
- Stop display name (bold)
- Distance + walking time (e.g., "350m • 4 min walk")
- List of shuttle arrivals for that stop:
  - Route code badge (colored pill)
  - ETA text ("2 min", "Arriving", etc.)
  - Capacity indicator (occupancy % or crowd level text)

**Data Flow:**
1. Watch `positionStreamProvider` for GPS location
2. Fetch `/nearby-stops?lat=...&lng=...` → shows cards
3. For each visible stop, fetch `/shuttles?stop=...` → shows ETAs
4. When user taps a route badge, fetch `/checkpoints?route=...` → draw polyline on map
5. Optionally fetch `/active-buses?route=...` → show bus markers

**Polling:**
- Nearby stops: re-fetch when location changes (distanceFilter: 15m) or every 20s
- Shuttles: every 10s while bottom sheet visible
- Active buses: every 10-15s while route overlay active

**States:**
- Loading: Shimmer placeholders in bottom sheet
- Error: Error card with retry button
- Empty: "No stops nearby" message
- Location denied: Card explaining how to enable location

---

### 4.2 Search & Routing (Tab 2: "Plan")

**Based on:** Route Planner v3 (search + map + bottom sheet) and Route Planner v2 (result detail).

#### 4.2.1 Search State (before route computed)

**Layout — From Route Planner v3:**
- Back button (circular, white shadow) + origin/destination input card:
  - Origin field: "Current Location" icon (blue) + text input
  - Divider line
  - Destination field: "location_on" icon (red) + text input
  - Swap button (swap_vert)
- When typing: autocomplete dropdown with stops + buildings from cached lists

**Autocomplete:**
- Source: `/stops` + `/buildings` (cached FutureProvider)
- Match on: name, longName, shortName, caption (stops) / name (buildings)
- Show "Current Location" as first option always
- Differentiate stops vs buildings with subtle icon/label

#### 4.2.2 Route Results (after submitting from+to)

**Layout — From Route Planner v3 bottom sheet:**
- Full-screen map in background with route polyline
- Bottom sheet with drag handle:
  - "Suggested Routes" title + arrival estimate
  - List of route summary cards

**Route Summary Card (compact, from v3):**
- Total time (large, bold): "18 min"
- Label: "FASTEST" for best route
- Route badges (colored pills): e.g., `[L2] > [BUS 104]`
- Estimated frequency: "Every 6 min"
- Status line: "Leaves in 3 mins from Platform 4" (if available)
- Selected card: blue tinted background + blue border

#### 4.2.3 Route Detail View (on tap)

**Layout — From Route Planner v2:**
- Header: "Route to {destination}" + subtitle "Leave now from {origin}" + filter icon
- Small map preview (h-32, rounded-xl) with "LIVE TRAFFIC" badge
- Tabs (optional if single route): "Fastest" / "Fewest Transfers" / "Least Walking"
- Expanded route card with:
  - Header bar: "14 min • 08:42 — 08:56" + real-time status + mode icons
  - Step timeline:
    - Walk step: gray circle + walk icon, "Walk to {stop}" + "2 min • 150m"
    - Bus step: blue circle + bus icon, "{Route} toward {direction}" + "9 min • 4 stops" + crowd level
    - Arrive step: outlined blue circle + location icon, "Arrive at {destination}"
  - "START NAVIGATION" button (primary blue, full width)

**Data Flow:**
1. Cache `/stops` + `/buildings` for autocomplete
2. When "Current Location" used as origin → resolve via GPS + `/nearby-stops`
3. Submit: `GET /route?from=...&to=...` → receive `RoutePlanResult`
4. Render legs as timeline steps
5. Optional: fetch `/checkpoints?route=...` for map polyline

**Edge Cases:**
- 404 → "Location not found" inline error
- 422 → "No route available" friendly card
- Network error → retry-able error state

---

### 4.3 Active Transit (New Screen)

**Based on:** Active Transit v1 design.

**Access:** Tap "START NAVIGATION" from route detail → push this screen.

**Layout:**
- Header: Back button + "{Route}: {Description}" + red "Exit" pill button
- Map section: 4:3 aspect ratio, rounded-2xl, shows route polyline + current bus marker
- Status card (slate-50 bg, rounded-2xl):
  - "Live Updates" with pulsing green dot
  - "Get off in X stops" (large bold)
  - Current destination stop + time remaining
  - Progress bar (% complete)
  - "Next: {upcoming stop}" info line
- Stops timeline (vertical):
  - Passed stops: filled blue dot + blue connector, gray text
  - Approaching: outlined blue dot, primary-colored label, bold text
  - Future stops: gray outlined dot, gray connector
  - Destination: blue circle with flag icon, bold text

**Data Flow:**
1. Use the route legs from `RoutePlanResult` to build the stops timeline
2. Poll `/active-buses?route=...` every 10s to update bus position on map
3. Poll `/shuttles?stop=...` for the next stop to get live ETA
4. Calculate trip progress from stops passed vs total stops
5. When user arrives (or taps "Exit"), pop back to route results

**Note:** This is a **derived** screen. The backend doesn't have a dedicated "active trip" endpoint. We compute progress from route legs + live bus position.

---

### 4.4 Favorites (Tab 3: "Saved")

**Layout:**
- Section: "Favorite Stops" — list of saved_stop_cards with live ETAs
- Section: "Favorite Routes" — list of favorite_route_cards
- Section: "Recent Searches" — compact list of recent from→to pairs

**Saved Stop Card:**
- Stop name (bold)
- Next 2 shuttle ETAs (fetched from `/shuttles`)
- Tap → navigate to map centered on that stop

**Favorite Route Card:**
- "{from} → {to}" label
- Tap → re-compute route

**Interactions:**
- Swipe to delete favorites
- Toggle favorite via heart/bookmark icon on stop cards / route results
- Persist via Hive: `favorite_stops` (List<String>), `favorite_routes` (List<String serialized as "from|to">), `recent_searches`

---

### 4.5 Alerts & Status (Tab 4: "Alerts")

**Based on:** Service Alerts Light design.

**Layout:**
- Sticky header: back button + "Transit Alerts" centered + search icon
- Tabs: "All" | "Service Updates" | "Maintenance" (with border-b indicator)
- **Current Alerts** section:
  - "CURRENT ALERTS" uppercase header + "3 NEW" badge
  - List of alert cards
- **Past Alerts** section:
  - "PAST ALERTS" uppercase header (gray text)
  - Alert cards with reduced opacity + gray bg

**Alert Card:**
- Left: Icon container (size-12, rounded-lg) with semantic color bg:
  - Error alerts: red bg + warning icon
  - Maintenance: orange bg + settings_suggest icon
  - Info: blue bg (primary/10) + info icon
  - Resolved: gray bg + check_circle icon
- Right: Title (bold) + timestamp (gray, right-aligned) + description text

**Weather Card (separate section or integrated):**
- Temperature, weather condition icon, wind speed
- Precipitation probability for next hour
- Fetched from `/weather?lat=...&lng=...`

**Data Flow:**
- `/announcements` + `/ticker-tapes` polled every 30s
- `/weather` polled every 5 min
- Map alerts to priority: "Critical" → red, "Roadworks"/"Maintenance" → orange, others → blue
- Separate current vs past based on status field ("Active" vs resolved)

---

## 5. Navigation Graph (GoRouter)

```dart
StatefulShellRoute.indexedStack(
  branches: [
    // Tab 0: Explore (Map Discovery)
    StatefulShellBranch(routes: [
      GoRoute(path: '/', builder: MapDiscoveryScreen),
    ]),
    // Tab 1: Plan (Search & Routing)
    StatefulShellBranch(routes: [
      GoRoute(path: '/search', builder: SearchRoutingScreen),
      GoRoute(path: '/search/detail', builder: RouteDetailScreen),
      GoRoute(path: '/search/active', builder: ActiveTransitScreen),
    ]),
    // Tab 2: Saved (Favorites)
    StatefulShellBranch(routes: [
      GoRoute(path: '/favorites', builder: FavoritesScreen),
    ]),
    // Tab 3: Alerts
    StatefulShellBranch(routes: [
      GoRoute(path: '/alerts', builder: AlertsScreen),
    ]),
  ],
  builder: BottomNavShell,  // Shared bottom navigation
)
```

### Bottom Navigation Bar

From designs, 4 tabs with icons:
1. **Explore** — `map` icon (or `explore`)
2. **Plan** — `route` icon (filled when active)
3. **Saved** — `bookmark` icon
4. **Alerts** — `notifications` icon (filled when active)

Style: white bg, backdrop blur, border-t, primary blue for selected, slate-400 for unselected, text-[10px] uppercase tracking-widest labels.

---

## 6. Theme Implementation

The theme should support **light mode** (matching the Stitch designs) and optionally dark mode.

### 6.1 Light Theme (Primary)

```dart
class AppTheme {
  static const Color primary = Color(0xFF135BEC);
  static const Color primaryLight = Color(0xFF3B7BF6);
  
  // Surfaces
  static const Color background = Color(0xFFF8FAFC);    // slate-50
  static const Color surface = Color(0xFFFFFFFF);        // white
  static const Color surfaceMuted = Color(0xFFF1F5F9);   // slate-100
  
  // Borders
  static const Color border = Color(0xFFE2E8F0);        // slate-200
  static const Color borderLight = Color(0xFFF1F5F9);   // slate-100
  
  // Text
  static const Color textPrimary = Color(0xFF0F172A);    // slate-900
  static const Color textSecondary = Color(0xFF64748B);  // slate-500
  static const Color textMuted = Color(0xFF94A3B8);      // slate-400
  
  // Semantic
  static const Color success = Color(0xFF059669);        // emerald-600
  static const Color warning = Color(0xFFD97706);        // amber-600
  static const Color error = Color(0xFFDC2626);          // red-600
  static const Color orange = Color(0xFFEA580C);         // orange-600
  
  // Semantic backgrounds
  static const Color errorBg = Color(0xFFFEE2E2);       // red-100
  static const Color warningBg = Color(0xFFFED7AA);      // orange-100
  static const Color infoBg = Color(0xFFDBEAFE);         // blue-100 (primary/10)
  static const Color successBg = Color(0xFFD1FAE5);      // emerald-100
  static const Color mutedBg = Color(0xFFE2E8F0);        // slate-200
}
```

### 6.2 Font Configuration

```yaml
# pubspec.yaml — add Google Fonts or bundle locally
dependencies:
  google_fonts: ^6.2.1   # For Plus Jakarta Sans + Inter
```

Or bundle the fonts in `assets/fonts/` and declare in pubspec.yaml.

---

## 7. Polling & Lifecycle Management

### 7.1 Polling Strategy

All polling MUST be lifecycle-aware:
- Pause when screen/tab not visible
- Resume when screen becomes visible
- Cancel on dispose

Use `Timer.periodic` inside `ConsumerStatefulWidget` with `didChangeDependencies` / `dispose` pattern, or use Riverpod's `ref.onDispose()` for auto-cleanup.

| Data | Interval | Trigger |
|------|----------|---------|
| Nearby stops | 20s or on GPS move | Map Discovery visible |
| Shuttle ETAs | 10s | Stop card visible |
| Active buses | 10-15s | Route overlay active |
| Announcements | 30s | Alerts tab visible |
| Ticker tapes | 30s | Alerts tab visible |
| Weather | 5 min | Alerts tab visible |

### 7.2 Caching Policy

- `/stops`, `/buildings`, `/service-descriptions`: Cache aggressively (5-60 min)
- `/checkpoints`, `/schedule`, `/pickup-points`: Cache per-route (10 min)
- Real-time data: Don't cache client-side, rely on backend Caffeine cache

---

## 8. Error Handling

### 8.1 Error States (Required for Every Async View)

1. **Loading** — Shimmer placeholder matching the expected content shape
2. **Error** — Card with error icon, message, and "Retry" button
3. **Empty** — Friendly illustration + message (e.g., "No nearby stops found")
4. **Success** — Normal content

### 8.2 Network Error Handling

```dart
// ApiClient interceptor pattern:
// - 4xx → throw ApiException with human-readable message
// - 5xx → throw ApiException("Service temporarily unavailable")
// - Network error → throw ApiException("No internet connection")
// - Timeout → throw ApiException("Request timed out")
```

### 8.3 Experimental Endpoints

`/publicity` and `/bus-location` may return 500 from upstream. These are non-critical:
- Wrap in try-catch
- Show nothing if they fail (no error card)
- Never block UI on their failure

---

## 9. Flutter Best Practices (From SKILL.md)

### 9.1 State Management
- Always check `mounted` before `setState` after async operations
- Use `ValueKey` on list items to preserve state during reorder
- Cache Future results in fields, not in build method
- Use `const` constructors wherever possible

### 9.2 Widgets
- Don't use `context` in `initState` — use `didChangeDependencies`
- Prefer `SizedBox` over `Container` for fixed sizing (const-friendly)
- Extract expensive build logic into separate widgets

### 9.3 Async
- Cache Future in initState or field, not inside FutureBuilder
- Cancel timers, subscriptions, and controllers in `dispose()`
- Use CancelToken with Dio for in-flight request cancellation

### 9.4 Navigation (GoRouter)
- Use `StatefulShellRoute.indexedStack` to preserve tab state
- Don't use context after `Navigator.pop` — check `mounted`
- Always validate route arguments

### 9.5 Performance
- Use `ListView.builder` for all scrollable lists (lazy rendering)
- Set `itemExtent` when list items have fixed height
- Use `RepaintBoundary` around animated/frequently-repainted regions
- Prefer `AnimatedOpacity` / `FadeTransition` over `Opacity` widget
- Use `const` widget constructors to skip unnecessary rebuilds

### 9.6 Platform
- Wrap all platform channel calls in try-catch
- Handle null returns from platform (e.g., location permissions)

---

## 10. Implementation Order

### Milestone 1: Foundation Shell
1. `main.dart` — ProviderScope, Hive init, runApp
2. `app.dart` — MaterialApp.router
3. `theme.dart` — Light theme with correct colors/fonts
4. `router.dart` — GoRouter with 4-tab StatefulShellRoute
5. Bottom navigation shell widget
6. `api_client.dart` — Dio with base URL, timeouts, interceptors
7. `api_constants.dart` — URLs, timeouts
8. `api_exception.dart` — Typed errors

### Milestone 2: Data Layer
9. All 16 model classes with factory constructors + fromJson
10. `transit_service.dart` — All API methods
11. `favorites_repository.dart` — Hive CRUD
12. `providers.dart` — All Riverpod providers

### Milestone 3: Map Discovery
13. `map_discovery_screen.dart` — Google Maps + bottom sheet
14. `nearby_stop_card.dart` — Stop info + shuttle ETAs
15. `shuttle_arrival_tile.dart` — Individual ETA row
16. `capacity_indicator.dart` — Occupancy display
17. Location permission flow
18. 10s polling for shuttles

### Milestone 4: Search & Routing
19. `search_routing_screen.dart` — Map bg + floating input + bottom sheet
20. `from_to_input.dart` — Origin/destination with swap
21. `suggestion_tile.dart` — Autocomplete row
22. `route_summary_card.dart` — Compact route card
23. `route_detail_screen.dart` — Expanded timeline view (v2 design)
24. `route_detail_card.dart` — Full card with steps
25. `route_step_tile.dart` — Walk/bus/arrive step
26. `route_badge.dart` — Colored route code chip

### Milestone 5: Active Transit
27. `active_transit_screen.dart` — Trip tracking
28. `trip_status_card.dart` — Progress display
29. `stops_timeline.dart` — Vertical timeline

### Milestone 6: Favorites
30. `favorites_screen.dart` — Saved stops + routes + recents
31. `saved_stop_card.dart` — With live ETA polling
32. `favorite_route_card.dart` — Quick re-route

### Milestone 7: Alerts
33. `alerts_screen.dart` — Tabbed alerts with sections
34. `alert_card.dart` — Semantic alert display
35. `weather_card.dart` — Weather conditions

### Milestone 8: Shared Widgets + Polish
36. `loading_shimmer.dart` — Generic shimmer
37. `error_card.dart` — Retry-able error
38. `empty_state.dart` — Friendly empty
39. Animation polish (route card expand, sheet drag, tab switch)
40. `flutter analyze` clean

### Milestone 9: Testing
41. Unit tests: models fromJson, ETA formatter, weather mapper
42. Widget tests: route card rendering, alert list, stop card
43. Integration test: search → route → navigate flow

---

## 11. Key Design Patterns from HTML References

### 11.1 Card Pattern (Used Everywhere)
```
Container:
  decoration: rounded-xl or rounded-2xl
  border: 1px solid slate-200
  background: white (or primary/10 for selected)
  shadow: shadow-sm
  padding: 16px
```

### 11.2 Timeline Pattern (Route Steps, Active Transit)
```
Row:
  Column (32px wide):
    Circle (size-8):
      icon
    Vertical line (w-0.5, bg-slate-200)
  Column (flex-1):
    Title (semibold)
    Subtitle (xs, slate-500)
```

### 11.3 Bottom Sheet Pattern
```
Container:
  rounded-t-3xl (BorderRadius.vertical(top: Radius.circular(24)))
  shadow: upward shadow
  border-t: slate-100
  children:
    Drag handle (w-12 h-1.5 rounded-full bg-slate-200, centered)
    Header (title + subtitle)
    Scrollable content
```

### 11.4 Tab Bar Pattern
```
Row with border-b border-slate-200:
  Tab buttons:
    Active: border-b-2 border-primary, text-primary, font-bold
    Inactive: border-b-2 border-transparent, text-slate-400/500
```

### 11.5 Alert Card Pattern
```
Row:
  Icon container (size-12, rounded-lg, semantic-color bg):
    Material icon
  Column (flex-1):
    Row: Title (bold) + Timestamp (right-aligned, xs, gray)
    Description (sm, slate-500, mt-1)
```

### 11.6 Route Badge Pattern
```
Container:
  background: route-specific color (blue, green, orange, gray)
  rounded: default (4-8px)
  padding: px-2 py-1
  child: Row:
    Icon (tiny, white): directions_bus, subway, train
    Text (10px, bold, white): route code
```

---

## 12. Acceptance Criteria

- [ ] App launches with 4-tab bottom navigation (Explore, Plan, Saved, Alerts)
- [ ] Map Discovery shows Google Map with nearby stops + live shuttle ETAs
- [ ] Search supports autocomplete from stops + buildings
- [ ] Route computation renders legs as visual timeline
- [ ] Active transit screen tracks live trip progress
- [ ] Favorites persist across app restarts (Hive)
- [ ] Alerts show current announcements with semantic icons
- [ ] Weather card displays current conditions
- [ ] All screens have loading/error/empty states
- [ ] No crashes on network failure
- [ ] `flutter analyze` returns no issues
- [ ] Design matches the Stitch screenshots (light theme, #135BEC primary, Plus Jakarta Sans)
