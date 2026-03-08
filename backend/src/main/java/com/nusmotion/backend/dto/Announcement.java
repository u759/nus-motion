package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.OffsetDateTime;

/**
 * Service announcement from /Announcements.
 */
public record Announcement(
        @JsonProperty("ID") String id,
        @JsonProperty("Text") String text,
        @JsonProperty("Status") String status,
        @JsonProperty("Priority") String priority,
        @JsonProperty("Affected_Service_Ids") String affectedServiceIds,
        @JsonProperty("Created_On") OffsetDateTime createdOn,
        @JsonProperty("Created_By") String createdBy
) {}