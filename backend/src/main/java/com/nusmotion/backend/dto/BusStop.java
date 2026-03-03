package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Maps one bus stop from the upstream /BusStops response.
 *
 * LEARNING NOTE:
 * - Java records are ideal for DTOs: immutable, concise, equals/hashCode for free.
 * - @JsonProperty bridges the upstream PascalCase JSON to our camelCase fields.
 * - Jackson (the JSON library bundled with Spring Boot) uses these annotations
 *   during deserialization (JSON → Java) and serialization (Java → JSON).
 */
public record BusStop(
        @JsonProperty("caption") String caption,
        @JsonProperty("name") String name,
        @JsonProperty("LongName") String longName,
        @JsonProperty("ShortName") String shortName,
        @JsonProperty("latitude") double latitude,
        @JsonProperty("longitude") double longitude
) {}
