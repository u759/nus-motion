package com.nusmotion.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Binds the "nus.api.*" keys from application.properties.
 * Spring Boot automatically maps kebab-case properties to camelCase fields.
 *
 * LEARNING NOTE:
 * - @ConfigurationProperties is the type-safe way to read groups of related
 *   properties.  Compare with @Value("${nus.api.base-url}") which is per-field.
 * - The 'record' keyword (Java 16+) gives you an immutable config object for free.
 */
@ConfigurationProperties(prefix = "nus.api")
public record NusApiProperties(
        String baseUrl,
        String authHeader,
        String userAgent
) {}
