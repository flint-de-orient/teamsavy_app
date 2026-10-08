import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/tokens.dart';

class DateRange {
  const DateRange({this.start, this.end});
  final DateTime? start;
  final DateTime? end;
}

/// components/ui/DateRangeCalendar.tsx: month grid where holidays are red,
/// the weekly off day is muted, the chosen range is primary-light with
/// solid primary ends, and today has a ring. First tap sets the start, the
/// second the end (an earlier day restarts the range).
class DateRangeCalendar extends StatefulWidget {
  const DateRangeCalendar({
    super.key,
    required this.range,
    required this.onChanged,
    this.holidays = const {},
    this.weeklyOffDay = 'Sunday',
  });

  final DateRange range;
  final ValueChanged<DateRange> onChanged;

  /// "YYYY-MM-DD" -> holiday name.
  final Map<String, String> holidays;
  final String weeklyOffDay;

  @override
  State<DateRangeCalendar> createState() => _DateRangeCalendarState();
}

class _DateRangeCalendarState extends State<DateRangeCalendar> {
  late DateTime _month = DateTime(
    (widget.range.start ?? DateTime.now()).year,
    (widget.range.start ?? DateTime.now()).month,
  );

  static const _weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _tap(DateTime day) {
    final r = widget.range;
    if (r.start == null || r.end != null) {
      widget.onChanged(DateRange(start: day));
    } else if (day.isBefore(r.start!)) {
      widget.onChanged(DateRange(start: day));
    } else {
      widget.onChanged(DateRange(start: r.start, end: day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final first = DateTime(_month.year, _month.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday % 7));
    final last = DateTime(_month.year, _month.month + 1, 0);
    final gridEnd = last.add(Duration(days: 6 - (last.weekday % 7)));
    final days = <DateTime>[];
    for (var d = gridStart; !d.isAfter(gridEnd); d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(d);
    }
    final offIndex = _weekdays.indexOf(widget.weeklyOffDay);
    final today = DateTime.now();
    final r = widget.range;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Ts.rXl),
        border: Border.all(color: p.border),
        boxShadow: p.shadowXs,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _NavBtn(
                icon: LucideIcons.chevronLeft,
                onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: Text(
                  '${monthName(_month.month)} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: tx(14, weight: FontWeight.w600, color: p.foreground),
                ),
              ),
              _NavBtn(
                icon: LucideIcons.chevronRight,
                onTap: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Center(child: Text(d, style: tx(12, weight: FontWeight.w500, color: p.muted))),
              for (final day in days) _day(context, p, day, offIndex, today, r),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
            child: Row(
              children: [_legend(p, p.danger, 'Holiday'), const SizedBox(width: 16), _legend(p, p.primary, 'Selected')],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(TsPalette p, Color c, String label) => Row(
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: tx(12, color: p.muted)),
    ],
  );

  Widget _day(BuildContext context, TsPalette p, DateTime day, int offIndex, DateTime today, DateRange r) {
    final key = ymd(day);
    final holiday = widget.holidays[key];
    final inMonth = day.month == _month.month;
    final isStart = r.start != null && _same(day, r.start!);
    final isEnd = r.end != null && _same(day, r.end!);
    final edge = isStart || isEnd;
    final inRange = r.start != null && r.end != null && !day.isBefore(r.start!) && !day.isAfter(r.end!);
    final isToday = _same(day, today);
    final isOff = day.weekday % 7 == offIndex;

    Color? bg;
    Color fg = p.foreground;
    FontWeight weight = FontWeight.w400;
    if (!inMonth) {
      fg = p.muted.withValues(alpha: 0.4);
    } else if (edge) {
      bg = p.primary;
      fg = p.primaryForeground;
      weight = FontWeight.w600;
    } else if (inRange) {
      bg = p.primaryLight;
      fg = p.primary;
    } else if (holiday != null) {
      bg = p.dangerLight;
      fg = p.danger;
      weight = FontWeight.w600;
    } else if (isOff) {
      fg = p.muted;
    }

    final cell = GestureDetector(
      onTap: () => _tap(day),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: isToday && !edge ? Border.all(color: p.primary.withValues(alpha: 0.5)) : null,
        ),
        child: Text('${day.day}', style: tx(14, weight: weight, color: fg)),
      ),
    );
    return holiday == null ? cell : Tooltip(message: holiday, child: cell);
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ts.rLg),
      child: SizedBox(width: 28, height: 28, child: Icon(icon, size: 16, color: p.muted)),
    );
  }
}
