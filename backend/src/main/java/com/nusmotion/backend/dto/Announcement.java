package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Service announcement from /Announcements.
 */
public record Announcement(
        @JsonProperty("ID") String id,
        @JsonProperty("Text") String text,
        @JsonProperty("Status") String status,
        @JsonProperty("Priority") String priority,
        @JsonProperty("Affected_Service_Ids") String affectedServiceIds
) {}