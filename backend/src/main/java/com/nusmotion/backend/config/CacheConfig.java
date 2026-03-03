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
 *   For real-time bus data we keep it short (10 s); for static data like
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

        // You can register named caches with different specs later, e.g.:
        //   manager.registerCustomCache("busStops",
        //       Caffeine.newBuilder().expireAfterWrite(Duration.ofMinutes(5))
        //              .maximumSize(50).build());

        return manager;
    }
}
