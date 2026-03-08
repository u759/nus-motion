package com.nusmotion.backend.controller;

import com.nusmotion.backend.dto.Announcement;
import com.nusmotion.backend.dto.CheckPoint;
import com.nusmotion.backend.dto.RouteSchedule;
import com.nusmotion.backend.service.NusApiService;
import com.nusmotion.backend.service.RoutingService;
import com.nusmotion.backend.service.WeatherService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class BusControllerTest {

    private NusApiService nusApiService;
        private RoutingService routingService;
        private WeatherService weatherService;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        nusApiService = mock(NusApiService.class);
                routingService = mock(RoutingService.class);
                weatherService = mock(WeatherService.class);
                mockMvc = MockMvcBuilders.standaloneSetup(new BusController(nusApiService, routingService, weatherService)).build();
    }

    @Test
    void getCheckpointsReturnsCheckpointList() throws Exception {
        when(nusApiService.getCheckpoints("A1"))
                .thenReturn(List.of(new CheckPoint("P1", 1.2966, 103.7764, 1)));

        mockMvc.perform(get("/api/checkpoints").param("route", "A1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].PointID").value("P1"))
                .andExpect(jsonPath("$[0].routeid").value(1));

        verify(nusApiService).getCheckpoints("A1");
    }

    @Test
    void getAnnouncementsReturnsAnnouncementList() throws Exception {
        when(nusApiService.getAnnouncements())
                .thenReturn(List.of(new Announcement("100", "Test alert", "Active", "High", "A1,D1", null, null)));

        mockMvc.perform(get("/api/announcements"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].ID").value("100"))
                .andExpect(jsonPath("$[0].Text").value("Test alert"))
                .andExpect(jsonPath("$[0].Affected_Service_Ids").value("A1,D1"));

        verify(nusApiService).getAnnouncements();
    }

    @Test
    void getScheduleReturnsScheduleList() throws Exception {
        when(nusApiService.getRouteMinMaxTime("A1"))
                .thenReturn(List.of(new RouteSchedule("Weekday", "0700", "2300", "Normal")));

        mockMvc.perform(get("/api/schedule").param("route", "A1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].DayType").value("Weekday"))
                .andExpect(jsonPath("$[0].FirstTime").value("0700"))
                .andExpect(jsonPath("$[0].LastTime").value("2300"));

        verify(nusApiService).getRouteMinMaxTime("A1");
    }
}
