package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Route description metadata from /ServiceDescription.
 */
public record ServiceDescription(
        @JsonProperty("Route") String route,
        @JsonProperty("RouteDescription") String routeDescription,
        @JsonProperty("RouteLongName") String routeLongName
) {}
