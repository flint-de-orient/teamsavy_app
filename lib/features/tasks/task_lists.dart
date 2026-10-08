import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/tasks/page.tsx - My Tasks.
class MyTasksScreen extends StatelessWidget {
  const MyTasksScreen({super.key});

  static const _header = PageHeader(
    title: 'My Tasks',
    description: 'Work assigned to you, feeding your monthly KPI score.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/tasks',
      header: _header,
      builder: (context, data, reload) {
        final tasks = data.l('tasks');
        return [
          _header,
          if (tasks.isEmpty) const EmptyState('No tasks assigned yet.', icon: LucideIcons.listTodo),
          for (final t in tasks)
            MobileCard(
              onTap: () => context.push('/tasks/${t.s('id')}'),
              children: [
                MobileCardHeader(title: t.s('title'), action: TaskStatusBadge(t.s('status'))),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Type', value: typeLabelOf(t.s('type'))),
                  MobileCardRow(label: 'Weight', value: t.s('weight')),
                  MobileCardRow(label: 'Due', value: fmtDate(t.at('dueDate'))),
                ]),
              ],
            ),
        ];
      },
    );
  }
}

/// app/(app)/tasks/queue/page.tsx - every task company-wide (HR only).
class TaskQueueScreen extends StatelessWidget {
  const TaskQueueScreen({super.key});

  static const _header = PageHeader(
    title: 'Task Queue',
    description: 'Every task across the organization, company-wide.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/tasks/queue',
      header: _header,
      builder: (context, data, reload) {
        final tasks = data.l('tasks');
        return [
          _header,
          if (tasks.isEmpty) const EmptyState('No tasks yet.', icon: LucideIcons.clipboardList),
          for (final t in tasks)
            MobileCard(
              onTap: () => context.push('/tasks/${t.s('id')}'),
              children: [
                MobileCardHeader(title: t.s('title'), action: TaskStatusBadge(t.s('status'))),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Employee', value: t.s('employeeName')),
                  MobileCardRow(label: 'Type', value: typeLabelOf(t.s('type'))),
                  MobileCardRow(label: 'Due', value: fmtDate(t.at('dueDate'))),
                ]),
              ],
            ),
        ];
      },
    );
  }
}

/// app/(app)/tasks/approvals/page.tsx - submitted tasks awaiting the
/// viewer's verification (all of them for HR, direct reports otherwise).
class TaskApprovalsScreen extends StatelessWidget {
  const TaskApprovalsScreen({super.key});

  static PageHeader _header(bool isHr) => PageHeader(
        title: 'Task Approvals',
        description: isHr ? 'Every task awaiting verification.' : "Your direct reports' submitted tasks.",
      );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/tasks/approvals',
      header: _header(session.me?.isHr ?? false),
      builder: (context, data, reload) {
        final tasks = data.l('tasks');
        return [
          _header(data.b('isHr')),
          if (tasks.isEmpty) const EmptyState('Nothing awaiting your verification.', icon: LucideIcons.circleCheckBig),
          for (final t in tasks)
            MobileCard(
              onTap: () => context.push('/tasks/${t.s('id')}'),
              children: [
                MobileCardHeader(title: t.s('title')),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Employee', value: t.s('employeeName')),
                  MobileCardRow(label: 'Type', value: typeLabelOf(t.s('type'))),
                  MobileCardRow(label: 'Weight', value: t.s('weight')),
                ]),
              ],
            ),
        ];
      },
    );
  }
}
