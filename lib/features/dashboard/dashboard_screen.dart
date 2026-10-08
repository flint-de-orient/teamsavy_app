import '../../widgets/ts.dart';

const _leaveStatusTone = {'PENDING_MANAGER': BadgeTone.amber, 'PENDING_HR': BadgeTone.blue};
const _leaveStatusLabel = {'PENDING_MANAGER': 'Pending Manager', 'PENDING_HR': 'Pending HR'};

/// app/(app)/dashboard/page.tsx (HR / Tenant Admin home).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _header = PageHeader(title: 'Dashboard', description: 'Overview of appointments, employees and leave.');

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/dashboard',
      header: _header,
      builder: (context, data, reload) {
        final stats = data.m('stats');
        return [
          PageHeader(
            title: 'Dashboard',
            description: 'Overview of appointments, employees and leave.',
            actions: [TsButton(label: 'New Appointment Letter', onPressed: () => context.push('/appointments/new'))],
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              StatCard(
                label: 'Total Appointments',
                value: '${stats.i('totalAppointments')}',
                tone: CardTone.primary,
                icon: LucideIcons.fileSignature,
                onTap: () => context.go('/appointments'),
              ),
              StatCard(
                label: 'Issued This Month',
                value: '${stats.i('issuedThisMonth')}',
                tone: CardTone.success,
                icon: LucideIcons.trendingUp,
              ),
              StatCard(
                label: 'Active Employees',
                value: '${stats.i('activeEmployees')}',
                tone: CardTone.info,
                icon: LucideIcons.users,
                onTap: () => context.go('/employees'),
              ),
              StatCard(
                label: 'Pending Leave',
                value: '${stats.i('pendingLeaveCount')}',
                tone: CardTone.purple,
                icon: LucideIcons.clipboardList,
                onTap: () => context.go('/leave/queue'),
              ),
            ],
          ),
          TsCard(
            title: 'Recent Appointments',
            action: TsLink('View all', onTap: () => context.go('/appointments')),
            child: _DividedList(
              empty: 'No appointments yet.',
              children: [
                for (final a in data.l('recentAppointments'))
                  _ListRow(
                    title: a.s('candidateName'),
                    subtitle: '${a.s('designation')} · ${fmtDate(a.at('createdAt'))}',
                    trailing: TsBadge(
                      a.s('status') == 'ISSUED' ? 'Issued' : 'Draft',
                      tone: a.s('status') == 'ISSUED' ? BadgeTone.green : BadgeTone.amber,
                    ),
                    onTap: () => context.push('/appointments/${a.s('id')}'),
                  ),
              ],
            ),
          ),
          TsCard(
            title: 'Pending Leave Requests',
            action: TsLink('View all', onTap: () => context.go('/leave/queue')),
            child: _DividedList(
              empty: 'Nothing pending.',
              children: [
                for (final r in data.l('pendingLeaveRequests'))
                  _ListRow(
                    title: r.s('employeeName'),
                    subtitle: '${r.s('typeLabel')} · ${r.s('numDays')} day(s)',
                    trailing: TsBadge(
                      _leaveStatusLabel[r.s('status')] ?? r.s('status'),
                      tone: _leaveStatusTone[r.s('status')] ?? BadgeTone.slate,
                    ),
                    onTap: () => context.push('/leave/${r.s('id')}'),
                  ),
              ],
            ),
          ),
        ];
      },
    );
  }
}

class _DividedList extends StatelessWidget {
  const _DividedList({required this.children, required this.empty});
  final List<Widget> children;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(empty, style: tx(14, color: p.muted)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) Divider(height: 1, color: p.border), children[i]],
      ],
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.title, required this.subtitle, required this.trailing, required this.onTap});
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx(14, weight: FontWeight.w500, color: p.foreground),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: tx(12, color: p.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}
