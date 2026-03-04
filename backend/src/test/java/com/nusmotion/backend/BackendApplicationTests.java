package com.nusmotion.backend;

import com.nusmotion.backend.dto.*;
import com.nusmotion.backend.dto.Wrappers.ShuttleServiceResult;
import com.nusmotion.backend.controller.BuildingController;
import com.nusmotion.backend.controller.BusController;
import com.nusmotion.backend.service.BuildingService;
import com.nusmotion.backend.service.NusApiService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.client.HttpServerErrorException;

import java.util.List;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
class BackendApplicationTests {

	private MockMvc mockMvc;

	private NusApiService nusApiService;

	private BuildingService buildingService;

	@BeforeEach
	void setUp() {
		nusApiService = mock(NusApiService.class);
		buildingService = mock(BuildingService.class);

		mockMvc = MockMvcBuilders.standaloneSetup(
				new BusController(nusApiService),
				new BuildingController(buildingService)
		).build();
	}

	@Test
	@DisplayName("Application context loads successfully")
	void contextLoads() {
	}

	@Test
	@DisplayName("GET /api/stops returns list of bus stops")
	void getStopsReturnsBusStops() throws Exception {
		when(nusApiService.getBusStops()).thenReturn(List.of(
				new BusStop("COM 3", "COM3", "COM 3", "COM3", 1.294431, 103.775217)
		));

		mockMvc.perform(get("/api/stops"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].name").value("COM3"))
				.andExpect(jsonPath("$[0].LongName").value("COM 3"));
	}

	@Test
	@DisplayName("GET /api/shuttles?stop=... returns shuttle arrivals for a stop")
	void getShuttlesReturnsShuttleService() throws Exception {
		Shuttle shuttle = new Shuttle("A1", "2 min", "SBA1234A", "8 min", "SBA8888B", "SEA", "LSD");
		when(nusApiService.getShuttleService(eq("COM3")))
				.thenReturn(new ShuttleServiceResult("COM3", "COM 3", List.of(shuttle)));

		mockMvc.perform(get("/api/shuttles").param("stop", "COM3"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.name").value("COM3"))
				.andExpect(jsonPath("$.shuttles[0].name").value("A1"));
	}

	@Test
	@DisplayName("GET /api/active-buses?route=... returns active bus positions")
	void getActiveBusesReturnsActiveBusList() throws Exception {
		when(nusApiService.getActiveBuses("A1")).thenReturn(List.of(
				new ActiveBus("SBA1234A", 1.2966, 103.7764, 32, 90)
		));

		mockMvc.perform(get("/api/active-buses").param("route", "A1"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].veh_plate").value("SBA1234A"))
				.andExpect(jsonPath("$[0].speed").value(32));
	}

	@Test
	@DisplayName("GET /api/checkpoints?route=... returns route polyline checkpoints")
	void getCheckpointsReturnsCheckpointList() throws Exception {
		when(nusApiService.getCheckpoints("A1")).thenReturn(List.of(
				new CheckPoint("P1", 1.2966, 103.7764, 90287)
		));

		mockMvc.perform(get("/api/checkpoints").param("route", "A1"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].PointID").value("P1"));
	}

	@Test
	@DisplayName("GET /api/announcements returns service announcements")
	void getAnnouncementsReturnsAnnouncements() throws Exception {
		when(nusApiService.getAnnouncements()).thenReturn(List.of(
				new Announcement("100", "Test alert", "Active", "High", "A1,D1")
		));

		mockMvc.perform(get("/api/announcements"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].ID").value("100"))
				.andExpect(jsonPath("$[0].Text").value("Test alert"));
	}

	@Test
	@DisplayName("GET /api/schedule?route=... returns route operating hours")
	void getScheduleReturnsRouteSchedule() throws Exception {
		when(nusApiService.getRouteMinMaxTime("A1")).thenReturn(List.of(
				new RouteSchedule("Weekday", "0700", "2300", "Normal")
		));

		mockMvc.perform(get("/api/schedule").param("route", "A1"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].DayType").value("Weekday"))
				.andExpect(jsonPath("$[0].FirstTime").value("0700"));
	}

	@Test
	@DisplayName("GET /api/service-descriptions returns route descriptions")
	void getServiceDescriptionsReturnsList() throws Exception {
		when(nusApiService.getServiceDescriptions()).thenReturn(List.of(
				new ServiceDescription("A1", "KRT > PGP > KR MRT > CLB > KRT")
		));

		mockMvc.perform(get("/api/service-descriptions"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].Route").value("A1"))
				.andExpect(jsonPath("$[0].RouteDescription").value("KRT > PGP > KR MRT > CLB > KRT"));
	}

	@Test
	@DisplayName("GET /api/pickup-points?route=... returns pickup points")
	void getPickupPointsReturnsList() throws Exception {
		when(nusApiService.getPickupPoints("A1")).thenReturn(List.of(
				new PickupPoint("KRB-A1-S", "Kent Ridge Bus Terminal", "KR Bus Ter", 1.294068, 103.769836, "Kent Ridge Bus Terminal", 90287)
		));

		mockMvc.perform(get("/api/pickup-points").param("route", "A1"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].busstopcode").value("KRB-A1-S"))
				.andExpect(jsonPath("$[0].pickupname").value("Kent Ridge Bus Terminal"));
	}

	@Test
	@DisplayName("GET /api/ticker-tapes returns ticker tape alerts")
	void getTickerTapesReturnsList() throws Exception {
		when(nusApiService.getTickerTapes()).thenReturn(List.of(
				new TickerTape(null, null, "A1", "246", "Service delay due to heavy rain", "High", "Active")
		));

		mockMvc.perform(get("/api/ticker-tapes"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].ID").value("246"))
				.andExpect(jsonPath("$[0].Message").value("Service delay due to heavy rain"));
	}

	@Test
	@DisplayName("GET /api/publicity returns upstream publicity JSON when available")
	void getPublicityReturnsPayload() throws Exception {
		when(nusApiService.getPublicity()).thenReturn("{\"items\":[]}");

		mockMvc.perform(get("/api/publicity"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.items").isArray());
	}

	@Test
	@DisplayName("GET /api/publicity returns 502 when upstream endpoint fails")
	void getPublicityReturns502OnUpstreamFailure() throws Exception {
		when(nusApiService.getPublicity())
				.thenThrow(new HttpServerErrorException(HttpStatus.INTERNAL_SERVER_ERROR, "Upstream error"));

		mockMvc.perform(get("/api/publicity"))
				.andExpect(status().isBadGateway())
				.andExpect(jsonPath("$.upstreamStatus").value(500));
	}

	@Test
	@DisplayName("GET /api/bus-location returns upstream bus location JSON")
	void getBusLocationReturnsPayload() throws Exception {
		when(nusApiService.getBusLocation("A1", null))
				.thenReturn("{\"BusLocationResult\":{\"route\":\"A1\"}}");

		mockMvc.perform(get("/api/bus-location").param("route", "A1"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.BusLocationResult.route").value("A1"));
	}

	@Test
	@DisplayName("GET /api/bus-location returns 502 when upstream endpoint fails")
	void getBusLocationReturns502OnUpstreamFailure() throws Exception {
		when(nusApiService.getBusLocation("A1", null))
				.thenThrow(new HttpServerErrorException(HttpStatus.INTERNAL_SERVER_ERROR, "Upstream error"));

		mockMvc.perform(get("/api/bus-location").param("route", "A1"))
				.andExpect(status().isBadGateway())
				.andExpect(jsonPath("$.upstreamStatus").value(500));
	}

	@Test
	@DisplayName("GET /api/buildings returns deduplicated building list")
	void getBuildingsReturnsList() throws Exception {
		when(buildingService.getBuildings()).thenReturn(List.of(
				new Building("732229053", "Cendana College", "28 College Avenue West", "138533", 1.30814, 103.77248)
		));

		mockMvc.perform(get("/api/buildings"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].name").value("Cendana College"))
				.andExpect(jsonPath("$[0].elementId").value("732229053"));
	}

	@Test
	@DisplayName("GET /api/buildings/{name}/nearest-stop returns nearest stop details")
	void getNearestStopReturnsResult() throws Exception {
		when(buildingService.findNearestStop("COM3"))
				.thenReturn(new NearestStopResult(
						"COM3", 1.29458, 103.77458,
						"COM3", "COM 3", 1.294431, 103.775217,
						73.0
				));

		mockMvc.perform(get("/api/buildings/COM3/nearest-stop"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.buildingName").value("COM3"))
				.andExpect(jsonPath("$.busStopName").value("COM3"));
	}

	@Test
	@DisplayName("GET /api/buildings/{name}/nearest-stop returns 404 for unknown building")
	void getNearestStopReturns404WhenBuildingNotFound() throws Exception {
		when(buildingService.findNearestStop("Unknown Hall"))
				.thenThrow(new IllegalArgumentException("Building not found: Unknown Hall"));

		mockMvc.perform(get("/api/buildings/{name}/nearest-stop", "Unknown Hall"))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.error").value("Building not found: Unknown Hall"));
	}

}
