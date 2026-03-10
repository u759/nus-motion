package com.nusmotion.backend.config;

import com.github.benmanes.caffeine.cache.Caffeine;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;

/**
 * Configures the Caffeine cache manager with named caches.
 *
 * LEARNING NOTE:
 * - @EnableCaching activates Spring's cache proxy.  Any method annotated
 *   with @Cacheable("name") will check this cache first and skip execution
 *   if a cached value exists for the same key.
 * - TTL (time-to-live) controls how long data is considered "fresh".
 *   For real-time bus data we keep it short (5 s); for static data like
 *   bus stops we cache longer (5 min).
 * - maximumSize prevents unbounded memory growth.
 */
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public CacheManager cacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager();

        // Default spec for any cache not explicitly listed
        manager.setCaffeine(Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofSeconds(10))
                .maximumSize(200));

        manager.registerCustomCache("busStops",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofMinutes(5))
                .maximumSize(1)
                .build());

        manager.registerCustomCache("checkpoints",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofMinutes(10))
                .maximumSize(20)
                .build());

        manager.registerCustomCache("announcements",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofSeconds(15))
                .maximumSize(1)
                .build());

        manager.registerCustomCache("schedule",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofHours(1))
                .maximumSize(20)
                .build());

        manager.registerCustomCache("shuttleService",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofSeconds(5))
                .maximumSize(200)
                .build());

        manager.registerCustomCache("activeBuses",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofSeconds(5))
                .maximumSize(50)
                .build());

        manager.registerCustomCache("serviceDescriptions",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofHours(1))
                .maximumSize(1)
                .build());

        manager.registerCustomCache("pickupPoints",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofMinutes(10))
                .maximumSize(50)
                .build());

        manager.registerCustomCache("tickerTapes",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofSeconds(15))
                .maximumSize(1)
                .build());

        manager.registerCustomCache("publicity",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofMinutes(10))
                .maximumSize(1)
                .build());

        manager.registerCustomCache("busLocation",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofSeconds(10))
                .maximumSize(200)
                .build());

        manager.registerCustomCache("nearbyStops",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofSeconds(5))
                .maximumSize(500)
                .build());

        manager.registerCustomCache("routePlans",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofSeconds(10))
                .maximumSize(200)
                .build());

        manager.registerCustomCache("weather",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofMinutes(10))
                .maximumSize(200)
                .build());

        // Buildings data rarely changes — cache for 1 hour, single entry (full list)
        manager.registerCustomCache("buildings",
            Caffeine.newBuilder()
                .expireAfterWrite(Duration.ofHours(1))
                .maximumSize(1)
                .build());

        return manager;
    }
}
