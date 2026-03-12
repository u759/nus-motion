# Lessons Learned

**Every agent MUST read this file before starting work.** It captures recurring mistakes and verified solutions to prevent re-discovery.

---

## Backend

### JSON Field Names Are Case-Sensitive
The upstream NUS API uses mixed case (`LongName`, `ShortName`, `PointID`). Our DTOs must use `@JsonProperty` to map these exactly. Frontend models must match the backend JSON output field names — not the Java field names.

### URL-Encode Building Names
Building names in path variables (e.g., `/api/buildings/{name}/nearest-stop`) must be URL-encoded. Names contain spaces, slashes, and special characters.

### `/publicity` and `/bus-location` Are Unreliable
The upstream NUS endpoints `/publicity` and `/bus-location` frequently return errors or empty responses. Treat them as optional — never block on them.

### Cache Keys Must Include Parameters
`@Cacheable` without proper `key` SpEL expression caches the first call's result for all parameter values. Always specify `key = "#paramName"`.

---

## Frontend

### Model Fields Must Match Backend JSON Exactly
If the backend returns `{ "LongName": "..." }`, the Dart model must have a field that deserializes from `LongName` — not `longName` or `long_name`. This is the #1 recurring bug.

### Always Handle Three States: Loading, Error, Empty
Every `AsyncValue` consumer must handle `.loading`, `.error`, and `.data` (including empty data). Missing any state causes unhandled exceptions or blank screens.

### Use ShuttleService Vehicle Plates for Next Bus Selection
When highlighting which bus arrives next at a stop, use `arrivalTimeVehPlate` from the ShuttleService API — not `ActiveBus.first`. The ActiveBus list order is arbitrary; only ShuttleService knows which bus arrives next at a specific stop.

### Walking Time Must Come From Backend
Walking time is calculated ONLY in `RoutingService.walkingMinutes()` (backend). The frontend calls `/nearby-stops` with the user's location to get walking times. Never calculate walking time locally in the frontend — use the backend API as the single source of truth.

### Lifecycle-Aware Polling
Polling timers that don't pause when the screen is inactive waste battery and API calls. Use `WidgetsBindingObserver` to pause/resume.

### Don't Call APIs in Widget Build Methods
API calls must go through providers. Calling APIs in `build()` causes infinite rebuild loops.

---

## General

### Read Before Writing Tasks
Before creating a task assuming something isn't implemented, always read the actual code/state first. The #1 recurring mistake across agents.

### Small Tasks Only
Large tasks lead to large mistakes. Every task must be small enough to review in one pass. When in doubt — break it down further.

---

## Deployment

### Oracle Cloud iptables Rule Ordering
Oracle Cloud Ubuntu images have a default REJECT-ALL rule (typically at position 5) in the INPUT chain. Any ACCEPT rules inserted **after** this position are ignored — traffic hits the REJECT first. Always insert custom rules **before** the REJECT rule: `sudo iptables -I INPUT 5 -m state --state NEW -p tcp --dport 443 -j ACCEPT`.

### Caddy Needs Both Port 80 and 443 Open
Caddy uses port 443 for TLS-ALPN-01 ACME challenge and port 80 for HTTP→HTTPS redirects. If only port 80 is open, Caddy falls back to HTTP-only mode.

### systemd StartLimitBurst Goes in [Unit]
`StartLimitBurst` and `StartLimitIntervalSec` must go in the `[Unit]` section, not `[Service]`. Placing them in `[Service]` causes a warning.

---

<!-- Add new lessons above this line, under the appropriate section header -->
