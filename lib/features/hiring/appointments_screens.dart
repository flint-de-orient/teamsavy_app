import '../../widgets/ts.dart';
import 'widgets.dart';

TsBadge _statusBadge(String status) =>
    status == 'ISSUED' ? const TsBadge('Issued', tone: BadgeTone.green) : const TsBadge('Draft', tone: BadgeTone.amber);

/// app/(app)/appointments/page.tsx.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, this.q = '', this.status = '', this.page = 1});
  final String q;
  final String status;
  final int page;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late final _q = TextEditingController(text: widget.q);
  late String _status = widget.status;
  late String _appliedQ = widget.q;
  late String _appliedStatus = widget.status;
  late int _page = widget.page;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _filter() {
    FocusScope.of(context).unfocus();
    setState(() {
      _appliedQ = _q.text.trim();
      _appliedStatus = _status;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      title: 'Appointments',
      actions: [TsButton(label: 'New Appointment Letter', onPressed: () => context.push('/appointments/new'))],
    );
    return ApiScreen(
      path: '/appointments',
      query: {'q': _appliedQ, 'status': _appliedStatus, 'page': _page},
      header: header,
      builder: (context, data, reload) {
        final rows = data.l('appointments');
        return [
          header,
          ListFilterBar(
            controller: _q,
            placeholder: 'Search by name or memo no.',
            status: _status,
            statusOptions: const [
              SelectOption('', 'All statuses'),
              SelectOption('DRAFT', 'Draft'),
              SelectOption('ISSUED', 'Issued'),
            ],
            onStatusChanged: (v) => setState(() => _status = v),
            onFilter: _filter,
          ),
          if (rows.isEmpty) const EmptyState('No appointment letters found.'),
          for (final a in rows) _AppointmentCard(a),
          Pagination(
            page: data.i('page', 1),
            pageCount: data.i('totalPages', 1),
            onChanged: (p) => setState(() => _page = p),
          ),
        ];
      },
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard(this.a);
  final Json a;

  @override
  Widget build(BuildContext context) {
    final id = a.s('id');
    final regularizes = a.sn('regularizesEmployeeId');
    return MobileCard(
      onTap: () => context.push('/appointments/$id'),
      children: [
        MobileCardHeader(
          title: a.s('candidateName'),
          action: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              _statusBadge(a.s('status')),
              if (regularizes != null)
                GestureDetector(
                  onTap: () => context.push('/employees/$regularizes'),
                  child: const TsBadge('Regularization', tone: BadgeTone.purple),
                ),
            ],
          ),
        ),
        MobileCardRows(rows: [
          MobileCardRow(label: 'Designation', value: a.s('designation')),
          MobileCardRow(label: 'Memo No.', value: a.sn('memoNo') ?? '—'),
          MobileCardRow(label: 'Created', value: fmtDate(a.at('createdAt'))),
        ]),
        MobileCardFooter(
          child: Wrap(
            spacing: 16,
            children: [
              TsLink('View PDF', onTap: () => openHiringFile(context, '/api/appointments/$id/pdf')),
              TsLink('Download', onTap: () => openHiringFile(context, '/api/appointments/$id/pdf?download=1')),
            ],
          ),
        ),
      ],
    );
  }
}

/// app/(app)/appointments/[id]/page.tsx.
class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/appointments/$id',
      builder: (context, data, reload) {
        final a = data.m('appointment');
        final isDraft = data.b('isDraft');
        final isEditable = data.b('isEditable');
        final memoPreview = data.s('memoPreview');
        final promotedFrom = a.mN('promotedFromAppointment');
        final promoted = a.mN('promotedAppointment');
        final regularizing = a.mN('regularizesEmployee');
        final allowances = a.l('otherAllowances');
        final p = Ts.of(context);

        return [
          PlainHeader(
            a.s('candidateName'),
            subtitle: '${a.s('designation')} · ${a.s('status') == 'ISSUED' ? 'Issued' : 'Draft'}',
            actions: [
              if (isEditable) TsButton.secondary(label: 'Edit', onPressed: () => context.push('/appointments/$id/edit')),
              TsButton.secondary(
                label: isDraft ? 'Preview PDF' : 'View PDF',
                onPressed: () => openHiringFile(context, '/api/appointments/$id/pdf'),
              ),
              TsButton(
                label: 'Download PDF',
                onPressed: () => openHiringFile(context, '/api/appointments/$id/pdf?download=1'),
              ),
            ],
          ),
          if (promotedFrom != null)
            TsCard(
              tone: CardTone.purple,
              child: _LinkedSentence(
                before: 'Auto-created after ',
                linkText: promotedFrom.s('candidateName'),
                onTap: () => context.push('/appointments/${promotedFrom.s('id')}'),
                after: "'s offer was ${promotedFrom.has('offerDeclinedAt') ? 'declined on ${fmtDateTime(promotedFrom.at('offerDeclinedAt'))}' : 'marked expired on ${fmtDateTime(promotedFrom.at('offerExpiredAt'))}'}.",
              ),
            ),
          if (promoted != null)
            TsCard(
              tone: CardTone.purple,
              child: _LinkedSentence(
                before: 'This decline/expiry triggered an auto-promotion - see ',
                linkText: promoted.s('candidateName'),
                onTap: () => context.push('/appointments/${promoted.s('id')}'),
                after: "'s appointment.",
              ),
            ),
          TsCard(
            child: DetailList(rows: [
              if (regularizing != null)
                DetailRow(
                  label: 'Regularizing',
                  child: TsLink(regularizing.s('name'), onTap: () => context.push('/employees/${regularizing.s('id')}')),
                ),
              DetailRow(label: 'Memo No.', value: a.sn('memoNo') ?? '$memoPreview (pending issuance)'),
              DetailRow(
                label: 'Date',
                value: a.has('issueDate')
                    ? fmtDate(a.at('issueDate'))
                    : a.s('issueDateMode') == 'AUTO'
                        ? 'Auto (assigned at issuance)'
                        : '(not set)',
              ),
              DetailRow(label: "Father's Name", value: a.s('fatherName')),
              DetailRow(label: 'Date of Birth', value: fmtDate(a.at('dob'))),
              DetailRow(label: 'Aadhar No.', value: a.s('aadharNo')),
              DetailRow(label: 'Address', value: a.s('address')),
              DetailRow(label: 'Mobile No.', value: a.s('mobileNo')),
              DetailRow(label: 'Email', value: a.s('email')),
              DetailRow(label: 'Department', value: a.s('department')),
              a.has('reportingManagerId')
                  ? DetailRow(
                      label: 'Reporting Manager',
                      child: TsLink(a.s('reportingManager'),
                          onTap: () => context.push('/employees/${a.s('reportingManagerId')}')),
                    )
                  : DetailRow(label: 'Reporting Manager', value: a.sn('reportingManager') ?? '—'),
              DetailRow(label: 'Place of Posting', value: a.s('placeOfPosting')),
              DetailRow(label: 'Date of Joining', value: fmtDate(a.at('dateOfJoining'))),
              DetailRow(label: 'Probation Duration', value: '${a.i('probationMonths')} month(s)'),
              DetailRow(
                label: 'Compensation',
                value: a.s('compensationMode') == 'PROBATION_STIPEND'
                    ? 'Stipend ₹${fmtNumber(a.at('stipendAmount'), empty: '')}/month during probation'
                    : 'Regular pay from start',
              ),
              DetailRow(label: 'Pay Band', value: '${a.s('payBandName')} — ${rupee(a.at('payBandCTC'))} CTC'),
              if (allowances.isNotEmpty)
                DetailRow(
                  label: 'Other Allowances',
                  value: allowances.map((x) => '${x.s('name')}: ${rupee(x.at('amount'))}').join(', '),
                ),
              DetailRow(label: 'Work Mode', value: a.s('workMode')),
            ]),
          ),
          if (isDraft)
            TsCard(
              title: 'Issue this Appointment Letter',
              child: Gap(
                gap: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'This will assign memo no. '),
                      TextSpan(text: memoPreview, style: TextStyle(fontWeight: FontWeight.w700, color: p.foreground)),
                      const TextSpan(text: ", freeze the letter's data, and generate the final PDF. This cannot be undone."),
                    ]),
                    style: tx(14, color: p.muted, height: 1.5),
                  ),
                  ActionButton(
                    label: 'Issue Appointment Letter',
                    pendingLabel: 'Issuing...',
                    run: () => api.action('hiring.issueAppointment', args: [id]),
                    onDone: (r) {
                      // "Letter issued, but PDF generation failed" is an error
                      // that still changed the letter - reload so the Retry
                      // section appears, as the web's revalidatePath does.
                      if (!r.ok && context.mounted) {
                        toast(context, r.error!, error: true);
                        refreshBus.bump();
                      }
                    },
                  ),
                ],
              ),
            ),
          if (!isDraft) _IssuanceRecord(id: id, a: a),
          if (isEditable)
            TsCard(
              title: 'Danger Zone',
              child: Gap(
                gap: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Muted(isDraft
                      ? 'This draft has not been issued yet - deleting it is permanent.'
                      : 'This letter has been issued but not yet accepted - deleting it is permanent and frees up its memo number.'),
                  ActionButton(
                    label: 'Delete Appointment',
                    pendingLabel: 'Deleting...',
                    variant: TsButtonVariant.danger,
                    run: () => api.action('hiring.deleteAppointment', args: [id]),
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }
}

class _LinkedSentence extends StatelessWidget {
  const _LinkedSentence({required this.before, required this.linkText, required this.onTap, required this.after});
  final String before;
  final String linkText;
  final VoidCallback onTap;
  final String after;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(before, style: tx(14, color: p.foreground)),
        GestureDetector(
          onTap: onTap,
          child: Text(linkText, style: tx(14, color: p.foreground, decoration: TextDecoration.underline)),
        ),
        Text(after, style: tx(14, color: p.foreground)),
      ],
    );
  }
}

class _IssuanceRecord extends StatelessWidget {
  const _IssuanceRecord({required this.id, required this.a});
  final String id;
  final Json a;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final hasPdf = a.b('hasPdf');
    return TsCard(
      title: 'Issuance Record',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailList(rows: [
            DetailRow(label: 'Issued By', value: a.sn('issuedByName') ?? '—'),
            DetailRow(label: 'Issued At', value: a.has('issuedAt') ? fmtDateTime(a.at('issuedAt')) : '—'),
            DetailRow(label: 'Created By', value: a.s('createdByName')),
          ]),
          const SizedBox(height: 16),
          if (!hasPdf)
            Gap(
              gap: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusMessage.error('PDF has not been generated successfully yet.'),
                ActionButton(
                  label: 'Retry PDF Generation',
                  pendingLabel: 'Retrying...',
                  variant: TsButtonVariant.danger,
                  run: () => api.action('hiring.retryPdfGeneration', args: [id]),
                ),
              ],
            )
          else
            Gap(
              gap: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offer — Email & WhatsApp', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
                _SendOfferButton(id: id, offerSentAt: a.at('offerSentAt'), offerWhatsAppSentAt: a.at('offerWhatsAppSentAt')),
                if (a.has('offerAcceptedAt'))
                  StatusMessage.success('Offer accepted on ${fmtDateTime(a.at('offerAcceptedAt'))}.'),
                if (a.has('offerDeclinedAt'))
                  StatusMessage.error(
                      'Offer declined on ${fmtDateTime(a.at('offerDeclinedAt'))}${a.sn('declineReason') != null ? ' - "${a.s('declineReason')}"' : ''}.'),
                if (a.has('offerExpiredAt')) Muted('Offer link expired on ${fmtDateTime(a.at('offerExpiredAt'))}.'),
              ],
            ),
        ],
      ),
    );
  }
}

/// send-offer-button.tsx: keeps the action's whatsappWarning on screen.
class _SendOfferButton extends StatefulWidget {
  const _SendOfferButton({required this.id, required this.offerSentAt, required this.offerWhatsAppSentAt});
  final String id;
  final Object? offerSentAt;
  final Object? offerWhatsAppSentAt;

  @override
  State<_SendOfferButton> createState() => _SendOfferButtonState();
}

class _SendOfferButtonState extends State<_SendOfferButton> {
  bool _pending = false;
  String? _error;
  String? _warning;

  Future<void> _send() async {
    setState(() {
      _pending = true;
      _error = null;
      _warning = null;
    });
    final r = await runAction(context, () => api.action('hiring.sendOffer', args: [widget.id]), followRedirects: false);
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _warning = r.data?.sn('whatsappWarning');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.offerSentAt != null) Muted('Email sent on ${fmtDateTime(widget.offerSentAt)}.'),
        if (widget.offerWhatsAppSentAt != null) Muted('WhatsApp sent on ${fmtDateTime(widget.offerWhatsAppSentAt)}.'),
        if (_error != null) StatusMessage.error(_error),
        if (_warning != null) StatusMessage(_warning, kind: StatusKind.warning),
        TsButton.secondary(
          label: widget.offerSentAt != null ? 'Resend Offer (Email + WhatsApp)' : 'Send Offer (Email + WhatsApp)',
          pending: _pending,
          pendingLabel: 'Sending...',
          onPressed: _send,
        ),
      ],
    );
  }
}
