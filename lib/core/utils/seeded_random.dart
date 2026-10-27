import 'dart:math' as math;

/// Small, fast, deterministic pseudo random generator (xorshift128).
///
/// The Daily Challenge relies on it: the same seed always produces the exact
/// same piece sequence, on every device and every platform.
class SeededRandom {
  SeededRandom(int seed) : _state = _splitSeed(seed);

  /// Creates a generator from a string seed such as `2026-10-02-classic`.
  factory SeededRandom.fromString(String seed) {
    int hash = 0x811C9DC5;
    for (int i = 0; i < seed.length; i++) {
      hash ^= seed.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return SeededRandom(hash == 0 ? 0x9E3779B9 : hash);
  }

  int _state;

  static int _splitSeed(int seed) {
    final int cleaned = (seed.abs() | 1) & 0x7FFFFFFF;
    return cleaned == 0 ? 0x9E3779B9 : cleaned;
  }

  int _next() {
    int x = _state;
    x ^= (x << 13) & 0x7FFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0x7FFFFFFF;
    _state = x & 0x7FFFFFFF;
    return _state;
  }

  /// Uniform double in `[0, 1)`.
  double nextDouble() => _next() / 0x7FFFFFFF;

  /// Uniform integer in `[0, maxExclusive)`.
  int nextInt(int maxExclusive) {
    if (maxExclusive <= 0) {
      return 0;
    }
    return _next() % maxExclusive;
  }

  /// Uniform integer in `[min, max]`.
  int nextRange(int min, int max) => min + nextInt(max - min + 1);

  /// Returns `true` with the given [probability].
  bool chance(double probability) => nextDouble() < probability;

  /// Picks one element of [items]. Returns `null` for an empty list.
  T? pick<T>(List<T> items) {
    if (items.isEmpty) {
      return null;
    }
    return items[nextInt(items.length)];
  }

  /// Picks an element using relative [weights].
  T pickWeighted<T>(List<T> items, double Function(T item) weightOf) {
    if (items.isEmpty) {
      throw StateError('pickWeighted called with an empty list');
    }
    double total = 0;
    for (final T item in items) {
      total += math.max(0, weightOf(item));
    }
    if (total <= 0) {
      return items[nextInt(items.length)];
    }
    double cursor = nextDouble() * total;
    for (final T item in items) {
      cursor -= math.max(0, weightOf(item));
      if (cursor <= 0) {
        return item;
      }
    }
    return items.last;
  }

  /// Fisher-Yates shuffle.
  void shuffle<T>(List<T> items) {
    for (int i = items.length - 1; i > 0; i--) {
      final int j = nextInt(i + 1);
      final T tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }
}