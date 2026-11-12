/// Centralized date and time formatting utilities for Raksha Kawach.
///
/// Converts UTC timestamps to Asia/Kolkata (IST, UTC+05:30) and formats them
/// consistently across Attendance, Verification, and Admin Header views.
class AppDateTimeFormat {
  /// Standard offset for Indian Standard Time (UTC+05:30).
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Converts any [DateTime] to an equivalent [DateTime] representing Asia/Kolkata (IST).
  ///
  /// The resulting [DateTime] is marked as UTC so that Dart's local system timezone
  /// does not alter the hour, minute, day, or year calculations.
  static DateTime toIst(DateTime dt) {
    final utc = dt.isUtc ? dt : dt.toUtc();
    final istInstant = utc.add(istOffset);
    return DateTime.utc(
      istInstant.year,
      istInstant.month,
      istInstant.day,
      istInstant.hour,
      istInstant.minute,
      istInstant.second,
      istInstant.millisecond,
    );
  }

  /// Formats time in `HH:mm:ss IST` (or without timezone if [includeTimezone] is false).
  ///
  /// Example: `08:14:02 IST`
  static String formatTime(DateTime dt, {bool includeTimezone = true}) {
    final ist = toIst(dt);
    final h = ist.hour.toString().padLeft(2, '0');
    final m = ist.minute.toString().padLeft(2, '0');
    final s = ist.second.toString().padLeft(2, '0');
    return includeTimezone ? '$h:$m:$s IST' : '$h:$m:$s';
  }

  /// Formats time in 12-hour format with AM/PM: `08:14:02 AM IST`.
  static String formatTime12Hour(DateTime dt, {bool includeTimezone = true}) {
    final ist = toIst(dt);
    final period = ist.hour >= 12 ? 'PM' : 'AM';
    final hour12 = ist.hour == 0
        ? 12
        : (ist.hour > 12 ? ist.hour - 12 : ist.hour);
    final h = hour12.toString().padLeft(2, '0');
    final m = ist.minute.toString().padLeft(2, '0');
    final s = ist.second.toString().padLeft(2, '0');
    return includeTimezone ? '$h:$m:$s $period IST' : '$h:$m:$s $period';
  }

  /// Formats date in `dd MMM yyyy` format.
  ///
  /// Example: `10 Nov 2026`
  static String formatDate(DateTime dt) {
    final ist = toIst(dt);
    const months = [
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
    final month = months[ist.month - 1];
    final day = ist.day.toString().padLeft(2, '0');
    return '$day $month ${ist.year}';
  }

  /// Formats date and time: `10 Nov 2026, 08:14:02 IST`.
  static String formatDateTime(DateTime dt, {bool includeTimezone = true}) {
    final dateStr = formatDate(dt);
    final timeStr = formatTime(dt, includeTimezone: includeTimezone);
    return '$dateStr, $timeStr';
  }

  /// Formats the header date: `Tuesday, Nov 10, 2026`.
  static String formatHeaderDate(DateTime dt) {
    final ist = toIst(dt);
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
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
    final weekday = weekdays[ist.weekday - 1];
    final month = months[ist.month - 1];
    return '$weekday, $month ${ist.day}, ${ist.year}';
  }

  /// Compact scan time display showing time and indicating if not today.
  static String formatScanTimeTable(DateTime dt, {DateTime? referenceNow}) {
    final ist = toIst(dt);
    final nowIst = toIst(referenceNow ?? DateTime.now());
    final isToday =
        ist.year == nowIst.year &&
        ist.month == nowIst.month &&
        ist.day == nowIst.day;

    final time = formatTime(dt, includeTimezone: true);
    if (isToday) {
      return time;
    }
    final date =
        '${ist.day.toString().padLeft(2, '0')}/${ist.month.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  /// Returns the start of the specified IST day (defaults to today) converted to UTC.
  static DateTime getIstDayStartInUtc([DateTime? istDay]) {
    final ist = toIst(istDay ?? DateTime.now());
    final istMidnight = DateTime.utc(ist.year, ist.month, ist.day);
    return istMidnight.subtract(istOffset);
  }

  /// Returns the end of the specified IST day (defaults to today) converted to UTC.
  static DateTime getIstDayEndInUtc([DateTime? istDay]) {
    return getIstDayStartInUtc(istDay).add(const Duration(days: 1));
  }

  /// Whether [dt] falls within the same IST calendar day as [reference].
  static bool isSameIstDay(DateTime dt, [DateTime? reference]) {
    final istA = toIst(dt);
    final istRef = toIst(reference ?? DateTime.now());
    return istA.year == istRef.year &&
        istA.month == istRef.month &&
        istA.day == istRef.day;
  }
}
