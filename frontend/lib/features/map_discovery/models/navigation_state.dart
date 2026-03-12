import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/route_leg.dart';
import 'package:frontend/data/models/route_plan_result.dart';

/// Current phase of the navigation flow.
enum NavigationStatus {
  /// Default state — no destination selected.
  idle,

  /// User is searching for a destination.
  searching,

  /// Route options are displayed; user previewing a selected route.
  routePreview,

  /// Active turn-by-turn navigation in progress.
  navigating,

  /// User has reached the destination.
  arrived,
}

/// Sub-state when on a bus leg (ride mode).
/// Note: BusLegState is currently unused — live navigation is disabled for MVP.
enum BusLegState {
  /// Walking to the bus stop.
  walkingToStop,

  /// At the bus stop, waiting for the bus.
  waitingAtStop,

  /// On board the bus, heading to alighting stop.
  onBoard,
}

/// Immutable state representing the current navigation context.
class NavigationState {
  final NavigationStatus status;

  /// Custom origin building. Null means "Current Location" (use GPS).
  final Building? origin;
  final Building? destination;
  final RoutePlanResult? route;
  final int currentLegIndex;
  final double? currentLat;
  final double? currentLng;
  final String? nextInstruction;
  final DateTime? estimatedArrival;
  final String? errorMessage;
  final BusLegState? busLegState;
  final String? missedBusMessage;

  const NavigationState({
    this.status = NavigationStatus.idle,
    this.origin,
    this.destination,
    this.route,
    this.currentLegIndex = 0,
    this.currentLat,
    this.currentLng,
    this.estimatedArrival,
    this.nextInstruction,
    this.errorMessage,
    this.busLegState,
    this.missedBusMessage,
  });

  /// Returns true if navigation is actively tracking user position.
  /// Note: Live navigation is disabled for MVP — always returns false.
  bool get isNavigating => false;

  /// Returns true if there is an error to display.
  bool get hasError => errorMessage != null;

  /// Current leg being navigated, or null if no route.
  RouteLeg? get currentLeg =>
      (route != null && currentLegIndex < route!.legs.length)
      ? route!.legs[currentLegIndex]
      : null;

  /// Returns true if the user is on the last leg of the route.
  bool get isLastLeg =>
      route != null && currentLegIndex >= route!.legs.length - 1;

  NavigationState copyWith({
    NavigationStatus? status,
    Building? origin,
    Building? destination,
    RoutePlanResult? route,
    int? currentLegIndex,
    double? currentLat,
    double? currentLng,
    String? nextInstruction,
    DateTime? estimatedArrival,
    String? errorMessage,
    BusLegState? busLegState,
    String? missedBusMessage,
    bool clearOrigin = false,
    bool clearDestination = false,
    bool clearRoute = false,
    bool clearError = false,
    bool clearBusLegState = false,
    bool clearMissedBusMessage = false,
  }) {
    return NavigationState(
      status: status ?? this.status,
      origin: clearOrigin ? null : (origin ?? this.origin),
      destination: clearDestination ? null : (destination ?? this.destination),
      route: clearRoute ? null : (route ?? this.route),
      currentLegIndex: currentLegIndex ?? this.currentLegIndex,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      nextInstruction: nextInstruction ?? this.nextInstruction,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      busLegState: clearBusLegState ? null : (busLegState ?? this.busLegState),
      missedBusMessage: clearMissedBusMessage
          ? null
          : (missedBusMessage ?? this.missedBusMessage),
    );
  }
}

/// Riverpod StateNotifier managing navigation flow transitions.
class NavigationStateNotifier extends StateNotifier<NavigationState> {
  NavigationStateNotifier() : super(const NavigationState());

  /// Set a custom origin (non-GPS). Pass null to revert to "Current Location".
  void setOrigin(Building? building) {
    state = building != null
        ? state.copyWith(origin: building, clearRoute: true)
        : state.copyWith(clearOrigin: true, clearRoute: true);
  }

  /// User selected a destination from search results.
  /// Transitions: idle|searching → routePreview (awaiting route selection).
  void selectDestination(Building building) {
    state = state.copyWith(
      status: NavigationStatus.routePreview,
      destination: building,
      clearRoute: true,
      clearError: true,
      currentLegIndex: 0,
    );
  }

  /// User selected a specific route from the options panel.
  void selectRoute(RoutePlanResult route) {
    if (state.destination == null) return;
    state = state.copyWith(
      status: NavigationStatus.routePreview,
      route: route,
      currentLegIndex: 0,
      nextInstruction: route.legs.isNotEmpty
          ? route.legs.first.instruction
          : null,
      estimatedArrival: DateTime.now().add(
        Duration(minutes: route.totalMinutes),
      ),
      clearError: true,
    );
  }

  /// User deselected the current route (back from detail to suggestions).
  void deselectRoute() {
    if (state.destination == null) return;
    state = state.copyWith(
      status: NavigationStatus
          .routePreview, // Stay in route preview to show suggestions
      clearRoute: true,
      clearError: true,
      currentLegIndex: 0,
    );
  }

  /// User cancelled navigation or closed the panel.
  void cancelNavigation() {
    state = const NavigationState(status: NavigationStatus.idle);
  }

  /// Clear only the destination (used when swapping origin ↔ destination).
  void clearDestination() {
    state = state.copyWith(
      status: NavigationStatus.idle,
      clearDestination: true,
      clearRoute: true,
    );
  }

  /// Swap origin and destination.
  void swapOriginDestination() {
    if (state.destination == null) return;
    final oldOrigin = state.origin;
    final oldDest = state.destination;
    state = state.copyWith(
      origin: oldDest,
      destination: oldOrigin,
      clearOrigin: oldOrigin == null,
      clearRoute: true,
    );
  }

  /// Enter search mode (user tapped search bar).
  void beginSearch() {
    state = state.copyWith(
      status: NavigationStatus.searching,
      clearRoute: true,
      clearDestination: true,
      clearError: true,
    );
  }

  /// Set an error message (e.g., route fetch failed, GPS unavailable).
  void setError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  /// Clear error without changing other state.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Global provider for NavigationStateNotifier.
final navigationStateProvider =
    StateNotifierProvider<NavigationStateNotifier, NavigationState>(
      (ref) => NavigationStateNotifier(),
    );
