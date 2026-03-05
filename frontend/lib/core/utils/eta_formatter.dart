class EtaFormatter {
  static String format(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return 'N/A';
    if (raw == 'Arr' || raw == 'ARR') return 'Arriving';
    final parsed = int.tryParse(raw);
    if (parsed != null) {
      if (parsed <= 0) return 'Arriving';
      if (parsed == 1) return '1 min';
      return '$parsed min';
    }
    return raw;
  }
}
