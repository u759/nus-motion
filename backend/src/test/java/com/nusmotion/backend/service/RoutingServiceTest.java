package com.nusmotion.backend.service;

import com.nusmotion.backend.dto.BusStop;
import com.nusmotion.backend.dto.PickupPoint;
import com.nusmotion.backend.dto.RouteLeg;
import com.nusmotion.backend.dto.RoutePlanResult;
import com.nusmotion.backend.dto.ServiceDescription;
import com.nusmotion.backend.dto.Shuttle;
import com.nusmotion.backend.dto.Wrappers.ShuttleServiceResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class RoutingServiceTest {

    private NusApiService nusApiService;
    private BuildingService buildingService;
    private RoutingService routingService;

    @BeforeEach
    void setUp() {
        nusApiService = mock(NusApiService.class);
        buildingService = mock(BuildingService.class);
        routingService = new RoutingService(nusApiService, buildingService);
    }

    @Test
    void planRoutesSetsTransferBusLegCoordinatesWithoutChangingTransferWaitLeg() {
        BusStop origin = new BusStop("Origin Stop", "ORIGIN", "Origin Stop", "Origin", 1.3000, 103.7700);
        BusStop transfer = new BusStop("Transfer Stop", "TRANSFER", "Transfer Stop", "Transfer", 1.3100, 103.7800);
        BusStop destination = new BusStop("Destination Stop", "DEST", "Destination Stop", "Destination", 1.3200, 103.7900);

        when(nusApiService.getBusStops()).thenReturn(List.of(origin, transfer, destination));
        when(nusApiService.getServiceDescriptions()).thenReturn(List.of(
                new ServiceDescription("A1", "Origin to transfer", null),
                new ServiceDescription("B1", "Transfer to destination", null)
        ));
        when(nusApiService.getPickupPoints("A1")).thenReturn(List.of(
                new PickupPoint(1, "ORIGIN", "Origin Stop", "Origin", origin.latitude(), origin.longitude(), "Origin Stop", 1),
                new PickupPoint(2, "TRANSFER", "Transfer Stop", "Transfer", transfer.latitude(), transfer.longitude(), "Transfer Stop", 1)
        ));
        when(nusApiService.getPickupPoints("B1")).thenReturn(List.of(
                new PickupPoint(1, "TRANSFER", "Transfer Stop", "Transfer", transfer.latitude(), transfer.longitude(), "Transfer Stop", 2),
                new PickupPoint(2, "DEST", "Destination Stop", "Destination", destination.latitude(), destination.longitude(), "Destination Stop", 2)
        ));
        when(nusApiService.getShuttleService("ORIGIN")).thenReturn(new ShuttleServiceResult(
                "ORIGIN",
                "Origin Stop",
                List.of(new Shuttle("A1", "2 min", null, null, null, null, null))
        ));
        when(nusApiService.getShuttleService("TRANSFER")).thenReturn(new ShuttleServiceResult(
                "TRANSFER",
                "Transfer Stop",
                List.of(new Shuttle("B1", "3 min", null, null, null, null, null))
        ));

        List<RoutePlanResult> routes = routingService.planRoutes("ORIGIN", "DEST");

        assertThat(routes).hasSize(1);
        RoutePlanResult route = routes.getFirst();
        List<RouteLeg> busLegs = route.legs().stream()
                .filter(leg -> "BUS".equals(leg.mode()))
                .toList();

        assertThat(busLegs).hasSize(2);
        assertThat(busLegs.get(0).fromLat()).isEqualTo(origin.latitude());
        assertThat(busLegs.get(0).fromLng()).isEqualTo(origin.longitude());
        assertThat(busLegs.get(0).toLat()).isEqualTo(transfer.latitude());
        assertThat(busLegs.get(0).toLng()).isEqualTo(transfer.longitude());
        assertThat(busLegs.get(1).fromLat()).isEqualTo(transfer.latitude());
        assertThat(busLegs.get(1).fromLng()).isEqualTo(transfer.longitude());
        assertThat(busLegs.get(1).toLat()).isEqualTo(destination.latitude());
        assertThat(busLegs.get(1).toLng()).isEqualTo(destination.longitude());

        RouteLeg transferWaitLeg = route.legs().get(2);
        assertThat(transferWaitLeg.mode()).isEqualTo("WAIT");
        assertThat(transferWaitLeg.fromLat()).isNull();
        assertThat(transferWaitLeg.fromLng()).isNull();
        assertThat(transferWaitLeg.toLat()).isNull();
        assertThat(transferWaitLeg.toLng()).isNull();
    }
}
