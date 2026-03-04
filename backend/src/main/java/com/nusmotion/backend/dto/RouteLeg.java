package com.nusmotion.backend.dto;

/**
 * One leg of a computed route plan.
 */
public record RouteLeg(
        String mode,
        String instruction,
        Integer minutes,
        String routeCode,
        String fromStop,
        String toStop,
        Double fromLat,
        Double fromLng,
        Double toLat,
        Double toLng
) {}
