package com.nusmotion.backend.service;

import com.nusmotion.backend.dto.WeatherSnapshot;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.List;
import java.util.Map;

/**
 * Fetches weather conditions from Open-Meteo.
 */
@Service
public class WeatherService {

    private final RestClient weatherClient;

    public WeatherService(@Value("${weather.api.base-url}") String weatherBaseUrl) {
        this.weatherClient = RestClient.builder()
                .baseUrl(weatherBaseUrl)
                .build();
    }

    /**
     * Cached briefly because weather changes slowly and many users query nearby locations.
     */
    @Cacheable(value = "weather", key = "#lat + '|' + #lng")
    public WeatherSnapshot getWeather(double lat, double lng) {
        String uri = UriComponentsBuilder.fromPath("/forecast")
                .queryParam("latitude", lat)
                .queryParam("longitude", lng)
                .queryParam("current", "temperature_2m,weather_code,precipitation,wind_speed_10m")
                .queryParam("hourly", "precipitation_probability")
                .queryParam("forecast_hours", 2)
                .queryParam("timezone", "auto")
                .build()
                .encode()
                .toUriString();

        Object payloadRaw = weatherClient.get()
                .uri(uri)
                .retrieve()
                .body(Map.class);
        Map<String, Object> payload = asMap(payloadRaw);

        if (payload == null) {
            throw new IllegalStateException("Weather API returned empty response");
        }

        Map<String, Object> current = asMap(payload.get("current"));
        Map<String, Object> hourly = asMap(payload.get("hourly"));

        String timezone = String.valueOf(payload.getOrDefault("timezone", "GMT"));
        String time = String.valueOf(current.getOrDefault("time", ""));
        double temperature = toDouble(current.get("temperature_2m"));
        int weatherCode = toInt(current.get("weather_code"));
        double precipitation = toDouble(current.get("precipitation"));
        double windSpeed = toDouble(current.get("wind_speed_10m"));

        Integer nextHourPrecipitationProbability = null;
        Object probsRaw = hourly.get("precipitation_probability");
        if (probsRaw instanceof List<?> probs && !probs.isEmpty()) {
            // first element = current hour; second (if present) = next hour
            Object chosen = probs.size() > 1 ? probs.get(1) : probs.get(0);
            nextHourPrecipitationProbability = toInt(chosen);
        }

        return new WeatherSnapshot(
                timezone,
                time,
                temperature,
                weatherCode,
                precipitation,
                windSpeed,
                nextHourPrecipitationProbability
        );
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> asMap(Object value) {
        return value instanceof Map<?, ?> map ? (Map<String, Object>) map : Map.of();
    }

    private double toDouble(Object value) {
        if (value instanceof Number n) return n.doubleValue();
        if (value == null) return 0.0;
        try {
            return Double.parseDouble(String.valueOf(value));
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }

    private int toInt(Object value) {
        if (value instanceof Number n) return n.intValue();
        if (value == null) return 0;
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (NumberFormatException e) {
            return 0;
        }
    }
}
