/// Parses a backend timestamp and converts it to the device's local time.
///
/// The backend stores UTC times without a timezone suffix
/// (e.g. `2026-09-30T18:13:56`), which Dart would otherwise read as local time.
DateTime? parseServerTime(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  final hasZone = value.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value);
  return DateTime.tryParse(hasZone ? value : '${value}Z')?.toLocal();
}
