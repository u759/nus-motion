package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.OffsetDateTime;

/**
 * Alert with geographic location from /TickerTapes.
 */
public record TickerTape(
        @JsonProperty("Accident_Latitude") Double accidentLatitude,
        @JsonProperty("Accident_Longitude") Double accidentLongitude,
        @JsonProperty("Affected_Service_Ids") String affectedServiceIds,
        @JsonProperty("ID") String id,
        @JsonProperty("Message") String message,
        @JsonProperty("Priority") String priority,
        @JsonProperty("Status") String status,
        @JsonProperty("Display_From") OffsetDateTime displayFrom,
        @JsonProperty("Display_To") OffsetDateTime displayTo,
        @JsonProperty("Created_On") OffsetDateTime createdOn,
        @JsonProperty("Created_By") String createdBy
) {}
