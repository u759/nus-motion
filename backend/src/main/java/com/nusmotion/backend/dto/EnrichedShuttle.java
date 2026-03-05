package com.nusmotion.backend.dto;

/**
 * A shuttle arrival enriched with the computed "towards" destination,
 * derived from the route's ordered pickup-point sequence.
 */
public record EnrichedShuttle(
        String name,
        String arrivalTime,
        String arrivalTime_veh_plate,
        String nextArrivalTime,
        String nextArrivalTime_veh_plate,
        String passengers,
        String nextPassengers,
        String towards
) {
    public static EnrichedShuttle from(Shuttle s, String towards) {
        return new EnrichedShuttle(
                s.name(), s.arrivalTime(), s.arrivalTimeVehPlate(),
                s.nextArrivalTime(), s.nextArrivalTimeVehPlate(),
                s.passengers(), s.nextPassengers(), towards);
    }
}
