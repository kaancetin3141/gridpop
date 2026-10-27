/// Local-date helpers used by the Daily Challenge and the leaderboard.
///
/// Everything is based on the device local time zone on purpose: the challenge
/// must roll over at the player's midnight, not at UTC midnight.
class DateKeys {
  const DateKeys._();

  static final RegExp _keyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// `yyyy-mm-dd` key of [date].
  static String key(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Key of the current day.
  static String today() => key(DateTime.now());

  /// Seed string for the daily piece sequence.
  static String dailySeed({String salt = 'pieces'}) => '${today()}#$salt';

  /// Human readable short date, e.g. `02 Oct`.
  static String shortLabel(DateTime date) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final int index = date.month - 1;
    final String month =
        index >= 0 && index < months.length ? months[index] : '${date.month}';
    return '${date.day.toString().padLeft(2, '0')} $month';
  }

  /// Midnight of the day after [date].
  static DateTime nextDay(DateTime date) =>
      DateTime(date.year, date.month, date.day + 1);

  /// Difference in whole days between two day keys.
  ///
  /// The comparison is done in UTC so a daylight saving change (a 23 or 25
  /// hour local day) can never drop a day.
  static int daysBetween(String olderKey, String newerKey) {
    final DateTime older = parseKey(olderKey);
    final DateTime newer = parseKey(newerKey);
    final DateTime olderUtc = DateTime.utc(older.year, older.month, older.day);
    final DateTime newerUtc = DateTime.utc(newer.year, newer.month, newer.day);
    return newerUtc.difference(olderUtc).inDays;
  }

  /// Parses a `yyyy-mm-dd` key back into a local [DateTime].
  ///
  /// Never throws: keys read from storage are untrusted, and an out of range
  /// date (for example `275760-09-14`) would otherwise take the whole app down
  /// during start-up. Out of range components are clamped to a sane date.
  static DateTime parseKey(String key) {
    final List<String> parts = key.split('-');
    if (parts.length != 3) {
      return DateTime.now();
    }
    final int year = (int.tryParse(parts[0]) ?? 1970).clamp(1970, 9999);
    final int month = (int.tryParse(parts[1]) ?? 1).clamp(1, 12);
    final int day = (int.tryParse(parts[2]) ?? 1).clamp(1, 31);
    return DateTime(year, month, day);
  }

  /// True when [key] is a real `yyyy-mm-dd` day key.
  ///
  /// Rejects junk, impossible dates (`2026-02-30`) and years outside
  /// 1970..9999, so a tampered payload cannot poison the daily history.
  static bool isValidKey(String key) {
    if (!_keyPattern.hasMatch(key)) {
      return false;
    }
    return DateKeys.key(parseKey(key)) == key;
  }
}