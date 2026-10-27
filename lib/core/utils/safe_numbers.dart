/// Defensive readers for values coming back from persistent storage.
///
/// Local storage is user editable (especially on the web, where it is plain
/// `localStorage`), so every number read back has to be treated as untrusted
/// input. Besides the obvious negative values it can hold a string, a
/// fraction or even `Infinity`: `jsonDecode('1e999')` happily returns
/// `double.infinity`, and calling `.round()` on that throws.
library;

/// [raw] as an int, or `null` when it is not a finite number.
int? jsonInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is double) {
    if (!raw.isFinite) {
      return null;
    }
    return raw.round();
  }
  return null;
}

/// [raw] clamped to `min`..`max`, with [fallback] for unusable values.
int safeRange(Object? raw, {required int min, required int max, int fallback = 0}) {
  final int value = jsonInt(raw) ?? fallback;
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
