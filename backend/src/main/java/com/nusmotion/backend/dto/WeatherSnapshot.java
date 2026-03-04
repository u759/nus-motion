package com.nusmotion.backend.dto;

/**
 * Lightweight weather summary from Open-Meteo.
 */
public record WeatherSnapshot(
        String timezone,
        String time,
        double temperatureCelsius,
        int weatherCode,
        double precipitationMm,
        double windSpeedKph,
        Integer nextHourPrecipitationProbability
) {}
