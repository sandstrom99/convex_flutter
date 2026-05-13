import 'dart:convert';

Map<String, String> buildArgs(Map<String, dynamic> record) {
  return {for (var entry in record.entries) entry.key: jsonEncode(entry.value)};
}

/// Normalize a JSON string so that whole-number doubles (e.g. `42.0`) become
/// ints (`42`).
///
/// Dart's `jsonDecode` preserves the distinction between `1` (int) and `1.0`
/// (double). The web Convex client delivers integers for whole numbers, but
/// the Rust FFI client serialises all Convex `Float64` values with a decimal
/// point. This mismatch causes `as int` casts in DTOs to throw on mobile.
///
/// By re-encoding the decoded-and-normalised value we ensure consumers see
/// the same Dart types regardless of transport.
String normalizeJsonNumbers(String jsonString) {
  final decoded = jsonDecode(jsonString);
  final normalized = _normalizeValue(decoded);
  return jsonEncode(normalized);
}

dynamic _normalizeValue(dynamic value) {
  if (value is double &&
      value == value.truncateToDouble() &&
      !value.isInfinite &&
      !value.isNaN) {
    return value.toInt();
  }
  if (value is List) {
    return value.map(_normalizeValue).toList();
  }
  if (value is Map<String, dynamic>) {
    return {for (final e in value.entries) e.key: _normalizeValue(e.value)};
  }
  return value;
}
