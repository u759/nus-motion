package com.nusmotion.backend.dto;

import java.util.List;

/**
 * Full route planning response.
 */
public record RoutePlanResult(
        String from,
        String to,
        int totalMinutes,
        int walkingMinutes,
        int waitingMinutes,
        int busMinutes,
        int transfers,
        List<RouteLeg> legs
) {}
