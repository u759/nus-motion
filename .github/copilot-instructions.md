# NUS Motion — Copilot Instructions

> These instructions are **always-on** and apply to every Copilot interaction in this workspace.

## Project Overview
NUS Motion is a campus transit app: Spring Boot 4 backend (Java 21) + Flutter frontend (Dart 3.7). The backend proxies the NUS NextBus API with caching. The frontend provides real-time bus tracking, route planning, favorites, and alerts.

## Multi-Agent System
This project uses a multi-agent workflow. See `.github/agents/` for specialized agents:
- **experimental_macos** — Orchestrator (delegates, never codes directly)
- **Architect** — API contracts, schemas, ADRs
- **Frontend Lead** — Flutter/Riverpod/UI
- **Backend Lead** — Spring Boot/Java
- **QA Reviewer** — Code review (read-only)
- **DevOps** — Build tooling, CI/CD, Docker

## Shared Coordination
All inter-agent communication uses `docs/coordination/`:
- `tasks/` — task assignments per role
- `reviews/` — QA review outputs
- `decisions.md` — architecture decision log
- `lessons-learned.md` — recurring mistakes (read this before every task)
- `messages/` — inter-agent discussions

## Mandatory Rules (All Agents)
1. **Read `docs/coordination/lessons-learned.md` before starting any task.**
2. **Frontend models must match backend JSON field names exactly** (case-sensitive).
3. **No hardcoded secrets or API keys in source code.**
4. **Every async UI must handle loading, error, and empty states.**
5. **URL-encode building names in API path parameters.**
6. **Small tasks only.** If it touches more than 3 files, split it.

## Tech Stack Quick Reference
| Layer | Stack |
|-------|-------|
| Backend | Spring Boot 4.0.3, Java 21, Maven, Caffeine cache, WebClient |
| Frontend | Flutter ^3.11.0, Riverpod ^2.6.1, GoRouter ^15.1.2, Dio ^5.8.0 |
| Maps | Google Maps Flutter ^2.12.1, Geolocator ^13.0.2 |
| Storage | Hive ^1.1.0 (local-only, no auth) |
| API Spec | `docs/nus-nextbus-openapi.yaml` |
