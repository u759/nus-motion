package com.nusmotion.backend.controller;

import com.nusmotion.backend.dto.*;
import com.nusmotion.backend.dto.Wrappers.ShuttleServiceResult;
import com.nusmotion.backend.service.NusApiService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

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

    public BusController(NusApiService nusApiService) {
        this.nusApiService = nusApiService;
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
}
