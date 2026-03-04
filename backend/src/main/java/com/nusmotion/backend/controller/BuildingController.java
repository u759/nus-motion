package com.nusmotion.backend.controller;

import com.nusmotion.backend.dto.Building;
import com.nusmotion.backend.dto.NearestStopResult;
import com.nusmotion.backend.service.BuildingService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * REST controller for NUS building data and nearest-stop lookup.
 *
 * LEARNING NOTES:
 *
 * 1. This controller follows the same pattern as BusController:
 *    @RestController + @RequestMapping prefix + @CrossOrigin.
 *
 * 2. NEW CONCEPT — @PathVariable:
 *    Unlike @RequestParam (query string: ?stop=UTown), @PathVariable extracts
 *    a value from the URL path itself:
 *      GET /api/buildings/Helix%20House/nearest-stop
 *    The {name} placeholder maps to the method parameter.
 *
 * 3. NEW CONCEPT — ResponseEntity:
 *    Instead of returning the DTO directly, we wrap it in ResponseEntity so
 *    we can control the HTTP status code.  This lets us return 404 when a
 *    building isn't found, instead of a generic 500 error.
 *
 * 4. URL ENCODING: Building names may contain spaces.  The frontend must
 *    URL-encode them (e.g., "Helix House" → "Helix%20House").  Spring
 *    automatically decodes them back for us.
 *
 * ENDPOINTS:
 * ──────────
 * GET /api/buildings              → List all NUS buildings (deduplicated)
 * GET /api/buildings/{name}/nearest-stop  → Find nearest bus stop to a building
 */
@RestController
@RequestMapping("/api")
@CrossOrigin
public class BuildingController {

    private final BuildingService buildingService;

    /**
     * LEARNING NOTE — Same constructor injection pattern as BusController.
     * Spring sees this controller needs a BuildingService, finds the @Service bean,
     * and passes it in automatically.
     */
    public BuildingController(BuildingService buildingService) {
        this.buildingService = buildingService;
    }

    /**
     * GET /api/buildings
     * Returns all NUS buildings (deduplicated by name).
     * The frontend uses this list for the building search/autocomplete.
     */
    @GetMapping("/buildings")
    public List<Building> getBuildings() {
        return buildingService.getBuildings();
    }

    /**
     * GET /api/buildings/{name}/nearest-stop
     * Finds the nearest bus stop to the given building.
     *
     * LEARNING NOTE — Error Handling:
     * - If the building name doesn't match any known building, BuildingService
     *   throws IllegalArgumentException.
     * - We catch it here and return HTTP 404 with a JSON error message.
     * - This is a simple approach.  In larger apps you'd use @ExceptionHandler
     *   or @ControllerAdvice for centralized error handling.
     *
     * Example:
     *   curl http://localhost:8080/api/buildings/Helix%20House/nearest-stop
     *   → { "buildingName": "Helix House", "busStopName": "MUSEUM",
     *       "busStopDisplayName": "Museum", "distanceMeters": 234, ... }
     */
    @GetMapping("/buildings/{name}/nearest-stop")
    public ResponseEntity<?> getNearestStop(@PathVariable String name) {
        try {
            NearestStopResult result = buildingService.findNearestStop(name);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404)
                    .body(Map.of("error", e.getMessage()));
        }
    }
}
