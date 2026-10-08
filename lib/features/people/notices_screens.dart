import '../../widgets/ts.dart';
import 'widgets.dart';

const _hrDescription =
    'Draft with AI, review, and publish - published notices reach every concerned employee via WhatsApp.';

/// Some reads answer `{ redirect }` where the web page would redirect (a
/// draft opened at its view URL, a published notice at its edit URL); swap
/// to that screen instead of rendering.
List<Widget> redirectInstead(BuildContext context, String target) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) context.pushReplacement(target);
  });
  return const [LoadingBlock(count: 1)];
}

/// app/(app)/notices/page.tsx - HR/Admin see every notice (drafts too);
/// employees see the published ones addressed to them.
class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  PageHeader _header(BuildContext context, bool canWrite) => canWrite
      ? PageHeader(
          title: 'Circulars & Notices',
          description: _hrDescription,
          actions: [TsButton(label: 'New', icon: LucideIcons.plus, onPressed: () => context.push('/notices/new'))],
        )
      : const PageHeader(title: 'Notices', description: 'Circulars, office orders, and notices addressed to you.');

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/notices',
      header: _header(context, session.me?.isHr ?? false),
      builder: (context, data, reload) {
        final canWrite = data.b('canWrite');
        final notices = data.l('notices');
        if (canWrite) {
          return [
            _header(context, true),
            if (notices.isEmpty) const EmptyState('No circulars or notices yet.', icon: LucideIcons.megaphone),
            for (final n in notices)
              MobileCard(
                onTap: () => context.push(n.s('status') == 'DRAFT' ? '/notices/${n.s('id')}/edit' : '/notices/${n.s('id')}'),
                children: [
                  MobileCardHeader(
                    title: n.s('subject'),
                    action: n.s('status') == 'PUBLISHED'
                        ? const TsBadge('Published', tone: BadgeTone.green)
                        : const TsBadge('Draft', tone: BadgeTone.amber),
                  ),
                  MobileCardRows(rows: [
                    MobileCardRow(label: 'Type', value: n.s('typeLabel')),
                    MobileCardRow(label: 'Memo No.', value: n.s('memoNo', '—')),
                    MobileCardRow(label: 'Date', value: fmtDate(n.at('date'))),
                  ]),
                ],
              ),
          ];
        }
        return [
          _header(context, false),
          if (notices.isEmpty) const EmptyState('No notices yet.', icon: LucideIcons.megaphone),
          if (notices.isNotEmpty)
            Gap(
              gap: 8,
              children: [for (final n in notices) _EmployeeNoticeTile(n)],
            ),
        ];
      },
    );
  }
}

class _EmployeeNoticeTile extends StatelessWidget {
  const _EmployeeNoticeTile(this.n);
  final Json n;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return TsPanel(
      radius: Ts.rXl,
      onTap: () => context.push('/notices/${n.s('id')}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.s('subject'), style: tx(14, weight: FontWeight.w600, color: p.foreground)),
                const SizedBox(height: 2),
                Text(noticeMetaLine(n), style: tx(12, color: p.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronRight, size: 16, color: p.muted),
        ],
      ),
    );
  }
}

/// app/(app)/notices/[id]/page.tsx - the notice itself, plus delivery
/// status and per-recipient WhatsApp resend for HR/Admin.
class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/notices/$id',
      builder: (context, data, reload) {
        final redirect = data.sn('redirect');
        if (redirect != null) return redirectInstead(context, redirect);
        final n = data.m('notice');
        final delivery = data.mN('delivery');
        return [
          PageHeader(
            title: n.s('subject'),
            description: noticeMetaLine(n),
            actions: [
              if (n.b('hasPdf'))
                TsButton.secondary(
                  label: 'Download PDF',
                  icon: LucideIcons.fileDown,
                  onPressed: () => openWebFile(context, '/api/notices/$id/pdf'),
                ),
            ],
          ),
          TsCard(child: NoticeBody(n.s('bodyText'))),
          if (delivery != null)
            TsCard(
              title: 'Delivery',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Muted(
                    '${delivery.i('recipientCount')} recipient(s) · ${delivery.i('sentCount')} notified on WhatsApp'
                    "${delivery.i('failedCount') > 0 ? " · ${delivery.i('failedCount')} couldn't be reached" : ''}.",
                  ),
                  const SizedBox(height: 12),
                  for (final (i, r) in delivery.l('recipients').indexed)
                    _RecipientRow(
                      key: ValueKey(r.s('employeeId')),
                      noticeId: id,
                      recipient: r,
                      last: i == delivery.l('recipients').length - 1,
                    ),
                ],
              ),
            ),
        ];
      },
    );
  }
}

class _RecipientRow extends StatefulWidget {
  const _RecipientRow({super.key, required this.noticeId, required this.recipient, required this.last});
  final String noticeId;
  final Json recipient;
  final bool last;

  @override
  State<_RecipientRow> createState() => _RecipientRowState();
}

class _RecipientRowState extends State<_RecipientRow> {
  late String? _sentAt = widget.recipient.sn('whatsappSentAt');
  late String? _error = widget.recipient.sn('whatsappError');
  bool _pending = false;

  @override
  void didUpdateWidget(covariant _RecipientRow old) {
    super.didUpdateWidget(old);
    // A reload (pull-to-refresh) brings the server's latest outcome.
    if (old.recipient != widget.recipient && !_pending) {
      _sentAt = widget.recipient.sn('whatsappSentAt');
      _error = widget.recipient.sn('whatsappError');
    }
  }

  // Updates the row in place, like the web; no page reload.
  Future<void> _resend() async {
    setState(() => _pending = true);
    final r = await api.action(
      'people.resendNoticeWhatsApp',
      args: [widget.noticeId, widget.recipient.s('employeeId')],
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      if (r.ok) {
        _sentAt = DateTime.now().toUtc().toIso8601String();
        _error = null;
      } else {
        _error = r.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final error = _error;
    final sentAt = _sentAt;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: widget.last ? null : Border(bottom: BorderSide(color: p.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.recipient.s('employeeName'), style: tx(14, color: p.foreground)),
                if (sentAt != null && error == null)
                  Text('Sent ${fmtDateTime(sentAt)}', style: tx(12, color: p.muted)),
                if (error != null) Text(error, style: tx(12, color: p.danger, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TsBadge(
                error != null ? 'Failed' : (sentAt != null ? 'Sent' : 'Not sent'),
                tone: error != null ? BadgeTone.red : (sentAt != null ? BadgeTone.green : BadgeTone.slate),
              ),
              const SizedBox(height: 6),
              TsButton.secondary(
                label: 'Resend',
                pendingLabel: 'Sending...',
                pending: _pending,
                compact: true,
                onPressed: _resend,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
