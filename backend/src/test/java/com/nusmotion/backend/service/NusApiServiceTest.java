package com.nusmotion.backend.service;

import com.nusmotion.backend.dto.Announcement;
import com.nusmotion.backend.dto.CheckPoint;
import com.nusmotion.backend.dto.RouteSchedule;
import com.nusmotion.backend.dto.Wrappers.AnnouncementsResponse;
import com.nusmotion.backend.dto.Wrappers.AnnouncementsResult;
import com.nusmotion.backend.dto.Wrappers.CheckPointResponse;
import com.nusmotion.backend.dto.Wrappers.CheckPointResult;
import com.nusmotion.backend.dto.Wrappers.RouteMinMaxTimeResponse;
import com.nusmotion.backend.dto.Wrappers.RouteMinMaxTimeResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClient;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Answers.RETURNS_DEEP_STUBS;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class NusApiServiceTest {

    private RestClient nusApiClient;
    private NusApiService nusApiService;

    @BeforeEach
    void setUp() {
        nusApiClient = mock(RestClient.class, RETURNS_DEEP_STUBS);
        nusApiService = new NusApiService(nusApiClient);
    }

    @Test
    void getCheckpointsReturnsEmptyListWhenResponseIsNull() {
        when(nusApiClient.get()
                .uri("/CheckPoint?route_code={route}", "A1")
                .retrieve()
                .body(CheckPointResponse.class))
                .thenReturn(null);

        assertThat(nusApiService.getCheckpoints("A1")).isEmpty();
    }

    @Test
    void getAnnouncementsReturnsEmptyListWhenResponseIsNull() {
        when(nusApiClient.get()
                .uri("/Announcements")
                .retrieve()
                .body(AnnouncementsResponse.class))
                .thenReturn(null);

        assertThat(nusApiService.getAnnouncements()).isEmpty();
    }

    @Test
    void getRouteMinMaxTimeReturnsEmptyListWhenResponseIsNull() {
        when(nusApiClient.get()
                .uri("/RouteMinMaxTime?route_code={route}", "A1")
                .retrieve()
                .body(RouteMinMaxTimeResponse.class))
                .thenReturn(null);

        assertThat(nusApiService.getRouteMinMaxTime("A1")).isEmpty();
    }

    @Test
    void getCheckpointsReturnsDataWhenResponsePresent() {
        CheckPointResponse response = new CheckPointResponse(
                new CheckPointResult(List.of(new CheckPoint("P1", 1.29, 103.77, 1))));

        when(nusApiClient.get()
                .uri("/CheckPoint?route_code={route}", "A1")
                .retrieve()
                .body(CheckPointResponse.class))
                .thenReturn(response);

        assertThat(nusApiService.getCheckpoints("A1"))
                .extracting(CheckPoint::pointId)
                .containsExactly("P1");
    }

    @Test
    void getAnnouncementsReturnsDataWhenResponsePresent() {
        AnnouncementsResponse response = new AnnouncementsResponse(
                new AnnouncementsResult(List.of(new Announcement("1", "msg", "Active", "High", "A1"))));

        when(nusApiClient.get()
                .uri("/Announcements")
                .retrieve()
                .body(AnnouncementsResponse.class))
                .thenReturn(response);

        assertThat(nusApiService.getAnnouncements())
                .extracting(Announcement::id)
                .containsExactly("1");
    }

    @Test
    void getRouteMinMaxTimeReturnsDataWhenResponsePresent() {
        RouteMinMaxTimeResponse response = new RouteMinMaxTimeResponse(
                new RouteMinMaxTimeResult(List.of(new RouteSchedule("Weekday", "0700", "2300", "Normal"))));

        when(nusApiClient.get()
                .uri("/RouteMinMaxTime?route_code={route}", "A1")
                .retrieve()
                .body(RouteMinMaxTimeResponse.class))
                .thenReturn(response);

        assertThat(nusApiService.getRouteMinMaxTime("A1"))
                .extracting(RouteSchedule::dayType)
                .containsExactly("Weekday");
    }
}
