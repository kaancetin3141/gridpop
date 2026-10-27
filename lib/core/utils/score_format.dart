/// Number formatting without pulling in `intl`.
class ScoreFormat {
  const ScoreFormat._();

  /// `12345` -> `12,345`
  static String number(int value) {
    final bool negative = value < 0;
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return negative ? '-$buffer' : buffer.toString();
  }

  /// `12345` -> `12.3K` for compact HUD labels.
  static String compact(int value) {
    if (value < 1000) {
      return number(value);
    }
    if (value < 1000000) {
      final double thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands >= 100 ? 0 : 1)}K';
    }
    final double millions = value / 1000000;
    return '${millions.toStringAsFixed(millions >= 100 ? 0 : 1)}M';
  }

  /// `95` -> `1:35`
  static String clock(int totalSeconds) {
    final int safe = totalSeconds < 0 ? 0 : totalSeconds;
    final int minutes = safe ~/ 60;
    final int seconds = safe % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// `3661` seconds -> `1h 1m`
  static String duration(Duration value) {
    final int hours = value.inHours;
    final int minutes = value.inMinutes % 60;
    final int seconds = value.inSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// `1` -> `1st`, `2` -> `2nd`
  static String ordinal(int value) {
    final int mod100 = value % 100;
    if (mod100 >= 11 && mod100 <= 13) {
      return '${value}th';
    }
    switch (value % 10) {
      case 1:
        return '${value}st';
      case 2:
        return '${value}nd';
      case 3:
        return '${value}rd';
      default:
        return '${value}th';
    }
  }
}