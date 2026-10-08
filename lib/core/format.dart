import 'package:intl/intl.dart';

/// The web app's formatters (lib/format-date.ts and friends), reproduced
/// exactly: every date is shown in Asia/Kolkata with the en-IN locale, so a
/// value reads the same on a phone in any timezone as it does on the web.
///
/// IST is a fixed UTC+05:30 (no DST), so a plain offset is exact.
DateTime toIST(DateTime value) => value.toUtc().add(const Duration(hours: 5, minutes: 30));

DateTime? parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

/// `formatISTDate` -> "7/10/2026" (d/m/yyyy, no zero padding).
String fmtDate(Object? value, {String empty = '—'}) {
  final d = parseDate(value);
  if (d == null) return empty;
  final t = toIST(d);
  return '${t.day}/${t.month}/${t.year}';
}

/// `formatISTTime` -> "9:05:23 am".
String fmtTime(Object? value, {String empty = '—', bool seconds = true}) {
  final d = parseDate(value);
  if (d == null) return empty;
  final t = toIST(d);
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  final ss = t.second.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'am' : 'pm';
  return seconds ? '$h:$mm:$ss $ampm' : '$h:$mm $ampm';
}

/// `formatISTDateTime` -> "7/10/2026, 9:05:23 am".
String fmtDateTime(Object? value, {String empty = '—'}) {
  final d = parseDate(value);
  if (d == null) return empty;
  return '${fmtDate(d)}, ${fmtTime(d)}';
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "7 Oct 2026" - the `{ day: "numeric", month: "short", year: "numeric" }`
/// en-IN form a few pages use.
String fmtDateMedium(Object? value, {String empty = '—'}) {
  final d = parseDate(value);
  if (d == null) return empty;
  final t = toIST(d);
  return '${t.day} ${_monthsShort[t.month - 1]} ${t.year}';
}

String monthName(int month) => _months[month - 1];
String monthShort(int month) => _monthsShort[month - 1];

/// "YYYY-MM" -> "October 2026" (resolveMonthRange's label).
String monthLabel(String yyyyMm) {
  final parts = yyyyMm.split('-');
  if (parts.length != 2) return yyyyMm;
  final m = int.tryParse(parts[1]) ?? 1;
  return '${_months[m - 1]} ${parts[0]}';
}

/// The current month in IST as "YYYY-MM".
String currentMonthValue() {
  final t = toIST(DateTime.now());
  return '${t.year}-${t.month.toString().padLeft(2, '0')}';
}

/// "YYYY-MM" shifted by [delta] months.
String shiftMonth(String yyyyMm, int delta) {
  final parts = yyyyMm.split('-');
  var y = int.parse(parts[0]);
  var m = int.parse(parts[1]) + delta;
  while (m < 1) {
    m += 12;
    y--;
  }
  while (m > 12) {
    m -= 12;
    y++;
  }
  return '$y-${m.toString().padLeft(2, '0')}';
}

/// Today's IST date as "YYYY-MM-DD" (the value of a date input).
String todayValue() => dateValue(DateTime.now());

/// Any instant -> its IST calendar date as "YYYY-MM-DD".
String dateValue(DateTime value) {
  final t = toIST(value);
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// A local picker date (no timezone meaning) -> "YYYY-MM-DD".
String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final _inr = NumberFormat.decimalPattern('en_IN');

/// `toLocaleString("en-IN")` -> "12,34,567.5".
String fmtNumber(Object? value, {String empty = '—'}) {
  if (value == null) return empty;
  final n = value is num ? value : num.tryParse(value.toString());
  if (n == null) return value.toString();
  return _inr.format(n);
}

/// `₹` + en-IN grouping, the money format used everywhere on the web.
String rupee(Object? value, {String empty = '—'}) {
  if (value == null) return empty;
  final s = fmtNumber(value, empty: empty);
  return s == empty ? s : '₹$s';
}

/// Attendance "worked" minutes -> "8h 5m".
String workedTime(Object? minutes) {
  if (minutes == null) return '—';
  final m = minutes is num ? minutes.toInt() : int.tryParse(minutes.toString());
  if (m == null) return '—';
  return '${m ~/ 60}h ${m % 60}m';
}

/// "PENDING_MANAGER" -> "PENDING MANAGER" (replaces only the first `_`,
/// exactly like `status.replace("_", " ")` on the web).
String enumLabel(String value) => value.replaceFirst('_', ' ');

/// "PENDING_MANAGER" -> "Pending Manager".
String titleCase(String value) => value
    .split(RegExp(r'[_\s]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// "Arjun Mehta" -> "AM" (Topbar's initialsOf).
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  if (parts.isEmpty) return '?';
  final p = parts[0];
  return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
}

/// NotificationBell's timeAgo.
String timeAgo(Object? iso) {
  final d = parseDate(iso);
  if (d == null) return '';
  final minutes = DateTime.now().difference(d).inMinutes;
  if (minutes < 1) return 'just now';
  if (minutes < 60) return '${minutes}m ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h ago';
  final days = hours ~/ 24;
  if (days < 7) return '${days}d ago';
  final t = toIST(d);
  return '${t.day} ${_monthsShort[t.month - 1]}';
}

String plural(int n, String one, [String? many]) => n == 1 ? one : (many ?? '${one}s');
