import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/attendance/my/page.tsx: the last 31 days and the last 20
/// punches of the signed-in employee.
class MyAttendanceScreen extends StatelessWidget {
  const MyAttendanceScreen({super.key});

  static const _title = 'My Attendance';

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/attendance/my',
      header: const PageHeader(title: _title, description: 'Your daily status and recent punches.'),
      builder: (context, data, reload) {
        if (!data.b('authorized')) {
          return [const PageHeader(title: _title), StatusMessage.error('You are not authorized to view this page.')];
        }
        if (!data.b('hasEmployee')) {
          return [const PageHeader(title: _title), const Muted('No employee record is linked to your account.')];
        }
        final days = data.l('days');
        final punches = data.l('punches');
        return [
          const PageHeader(title: _title, description: 'Your daily status and recent punches.'),
          const SectionTitle('Daily Status', top: 0),
          if (days.isEmpty) const EmptyState('No attendance recorded yet.', icon: LucideIcons.calendarClock),
          for (final d in days)
            AttendanceDayCard(
              title: fmtDate(d.at('date')),
              day: d,
              footer: Align(
                alignment: Alignment.centerLeft,
                child: TsLink('Request a fix', onTap: () => context.push(d.s('fixHref'))),
              ),
            ),
          const SectionTitle('Recent Punches', top: 16),
          if (punches.isEmpty) const EmptyState('No punches yet.', icon: LucideIcons.fingerprint),
          for (final punch in punches)
            MobileCard(
              children: [
                MobileCardHeader(
                  title: fmtDateTime(punch.at('punchAt')),
                  action: TsBadge(punch.s('direction')),
                ),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Source', value: punch.s('source')),
                  if (punch.at('withinGeofence') != null)
                    MobileCardRow(
                      label: 'Geofence',
                      child: punch.b('withinGeofence')
                          ? const TsBadge('Inside', tone: BadgeTone.green)
                          : const TsBadge('Outside', tone: BadgeTone.red),
                    ),
                ]),
              ],
            ),
        ];
      },
    );
  }
}
