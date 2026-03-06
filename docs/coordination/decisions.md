# Architecture Decision Records

> Logged by the **Architect** agent. Every non-trivial design decision goes here.

---

## ADR-001: Thin Proxy Architecture
**Status:** Accepted
**Context:** NUS provides a NextBus API but it has no CORS headers, inconsistent field naming, and no caching. The Flutter app cannot call it directly.
**Decision:** Build a Spring Boot backend that acts as a thin proxy — forwarding requests to the NUS API, normalizing field names via DTOs, and caching responses in Caffeine.
**Consequences:** We own the API contract the frontend consumes. Upstream API changes only require backend updates. Trade-off: added infrastructure to maintain.

---

## ADR-002: Frontend-First Design Pipeline
**Status:** Accepted
**Context:** Building backend endpoints without knowing what the UI needs leads to wasted work and mismatched APIs.
**Decision:** Design screens as HTML mockups first (in `design/screens/`), extract requirements from the UI, then build backend endpoints to serve exactly what the UI needs.
**Consequences:** UI drives the API shape. Backend never builds speculative endpoints. Trade-off: sequential workflow, not parallel.

---

## ADR-003: Local-Only User Data
**Status:** Accepted
**Context:** NUS Motion doesn't require user accounts. Favorites, recent searches, and preferences are personal.
**Decision:** Store all user data locally via Hive (Flutter). No server-side user storage, no auth.
**Consequences:** Zero privacy/auth complexity. Trade-off: data doesn't sync across devices.

---

## ADR-004: Integrated Navigation State Machine
**Status:** Accepted
**Context:** The Plan screen is being deprecated. Navigation will be integrated into the Explore screen via a unified flow: search → route preview → navigate → arrived.
**Decision:** Model navigation as a finite state machine using Riverpod `StateNotifier<NavigationState>`. States: `idle`, `searching`, `routePreview`, `navigating`, `arrived`. The notifier owns all transitions and encapsulates navigation logic.
**Consequences:**
- Single source of truth for navigation state across Explore screen.
- UI subscribes to `NavigationStatus` to show/hide panels and sheets.
- Leg advancement logic remains in notifier; geofencing is external.
- Future extension: persist mid-navigation state for app restarts.
