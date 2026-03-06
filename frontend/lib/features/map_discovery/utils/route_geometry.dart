import 'dart:math' as math;

import 'package:frontend/data/models/checkpoint.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Returns a route-shaped bus polyline by clipping the nearest ordered segment
/// from a route's checkpoints between the boarding and alighting coordinates.
///
/// Returns `null` when there is not enough checkpoint data to produce a
/// meaningful clipped segment, allowing callers to fall back to a simple
/// straight line between the leg endpoints.
List<LatLng>? clipCheckpointSegment({
  required List<CheckPoint> checkpoints,
  required LatLng boardingPoint,
  required LatLng alightingPoint,
}) {
  if (checkpoints.length < 2) {
    return null;
  }

  final checkpointPoints = checkpoints
      .map((checkpoint) => LatLng(checkpoint.latitude, checkpoint.longitude))
      .toList(growable: false);

  final startIndex = _nearestCheckpointIndex(checkpointPoints, boardingPoint);
  final endIndex = _nearestCheckpointIndex(checkpointPoints, alightingPoint);

  if (startIndex == -1 || endIndex == -1 || startIndex == endIndex) {
    return null;
  }

  final lowerIndex = math.min(startIndex, endIndex);
  final upperIndex = math.max(startIndex, endIndex);
  final clippedPoints = checkpointPoints.sublist(lowerIndex, upperIndex + 1);

  if (clippedPoints.length < 2) {
    return null;
  }

  final orderedPoints = startIndex <= endIndex
      ? clippedPoints
      : clippedPoints.reversed.toList(growable: false);

  final polylinePoints = <LatLng>[];
  if (!_sameCoordinate(boardingPoint, orderedPoints.first)) {
    polylinePoints.add(boardingPoint);
  }
  polylinePoints.addAll(orderedPoints);
  if (!_sameCoordinate(alightingPoint, orderedPoints.last)) {
    polylinePoints.add(alightingPoint);
  }

  return polylinePoints.length >= 2 ? polylinePoints : null;
}

int _nearestCheckpointIndex(List<LatLng> checkpoints, LatLng target) {
  if (checkpoints.isEmpty) {
    return -1;
  }

  var nearestIndex = 0;
  var nearestDistance = double.infinity;

  for (var i = 0; i < checkpoints.length; i++) {
    final checkpoint = checkpoints[i];
    final latDelta = checkpoint.latitude - target.latitude;
    final lngDelta = checkpoint.longitude - target.longitude;
    final distance = (latDelta * latDelta) + (lngDelta * lngDelta);

    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestIndex = i;
    }
  }

  return nearestIndex;
}

bool _sameCoordinate(LatLng a, LatLng b) {
  const epsilon = 0.000001;
  return (a.latitude - b.latitude).abs() < epsilon &&
      (a.longitude - b.longitude).abs() < epsilon;
}
