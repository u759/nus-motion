String formatEta(String? arrivalTime) {
  if (arrivalTime == null || arrivalTime.isEmpty || arrivalTime == '-') {
    return 'N/A';
  }
  if (arrivalTime == 'Arr') {
    return 'Arriving';
  }
  final minutes = int.tryParse(arrivalTime);
  if (minutes != null) {
    return '$minutes min';
  }
  return arrivalTime;
}
