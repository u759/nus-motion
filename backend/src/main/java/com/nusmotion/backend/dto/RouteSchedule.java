package com.nusmotion.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Operating schedule row from /RouteMinMaxTime.
 */
public record RouteSchedule(
        @JsonProperty("DayType") String dayType,
        @JsonProperty("FirstTime") String firstTime,
        @JsonProperty("LastTime") String lastTime,
        @JsonProperty("ScheduleType") String scheduleType
) {}