import '../../widgets/ts.dart';
import 'widgets.dart';

const _leaveTypes = [
  SelectOption('EARNED', 'Earned Leave'),
  SelectOption('CASUAL', 'Casual Leave'),
  SelectOption('SICK', 'Sick Leave'),
  SelectOption('MATERNITY', 'Maternity Leave'),
  SelectOption('PATERNITY', 'Paternity Leave'),
  SelectOption('BEREAVEMENT', 'Bereavement Leave'),
  SelectOption('COMPENSATORY_OFF', 'Compensatory Off'),
  SelectOption('LEAVE_WITHOUT_PAY', 'Leave Without Pay'),
];

const _balanceCards = {
  'EARNED': ('Earned Leave', LucideIcons.calendarRange, CardTone.primary),
  'CASUAL': ('Casual Leave', LucideIcons.coffee, CardTone.info),
  'SICK': ('Sick Leave', LucideIcons.heartPulse, CardTone.purple),
};

/// app/(app)/employees/[id]/page.tsx - the full HR view of one employee.
class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/employees/$id',
      gap: 24,
      builder: (context, data, reload) {
        final e = data.m('employee');
        final active = e.s('status') == 'ACTIVE';
        final attendance = data.mN('attendance');
        return [
          PageHeader(
            title: e.s('name'),
            description: '${e.s('designation')} · ${e.s('department')}',
            actions: [
              TsButton.secondary(
                label: 'Edit',
                icon: LucideIcons.pencil,
                onPressed: () => context.push('/employees/$id/edit'),
              ),
              TsButton.secondary(
                label: 'Generate ID Card',
                icon: LucideIcons.idCard,
                onPressed: () => openWebFile(context, '/api/employees/$id/id-card?download=1'),
              ),
              if (data.b('canRegularize'))
                data.sn('pendingRegularizationId') != null
                    ? TsButton.secondary(
                        label: 'Regularization Pending',
                        onPressed: () => context.push('/appointments/${data.s('pendingRegularizationId')}'),
                      )
                    : TsButton.secondary(
                        label: 'Regularize to Permanent',
                        onPressed: () => context.push('/appointments/new?regularizeEmployeeId=$id'),
                      ),
              ActionButton(
                label: active ? 'Deactivate' : 'Reactivate',
                variant: active ? TsButtonVariant.danger : TsButtonVariant.secondary,
                icon: active ? LucideIcons.userX : LucideIcons.userCheck,
                run: () => api.action(
                  active ? 'people.deactivateEmployee' : 'people.reactivateEmployee',
                  fields: {'id': id},
                ),
              ),
            ],
          ),
          _ProfileCard(data: data),
          for (final b in data.l('balances')) _BalanceCard(b),
          _PortalAccessCard(id: id, portal: data.m('portal')),
          _DocumentsCard(id: id, docs: data.m('documents')),
          if (attendance != null) _AttendanceCard(id: id, attendance: attendance),
          TsCard(
            title: 'Prior Leave (before this system)',
            description:
                'Optional — record leave already availed this leave-year so balances start accurate. No certificate needed.',
            child: Gap(
              gap: 16,
              children: [
                Gap(
                  gap: 8,
                  children: [
                    for (final r in data.l('priorLeave')) _PriorLeaveRow(employeeId: id, record: r),
                    if (data.l('priorLeave').isEmpty) const Muted('No prior leave recorded.'),
                  ],
                ),
                _PriorLeaveForm(employeeId: id),
              ],
            ),
          ),
          TsCard(
            title: 'Danger Zone',
            child: FormActionButton(
              label: 'Delete Employee',
              pendingLabel: 'Deleting...',
              variant: TsButtonVariant.danger,
              confirm: "Delete ${e.s('name')}? This can't be undone.",
              run: () => api.action('people.deleteEmployee', args: [id]),
            ),
          ),
        ];
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final e = data.m('employee');
    final status = e.s('status');
    final probation = data.mN('probation');
    final manager = e.mN('manager');
    final appointment = e.mN('appointment');
    final payBand = e.mN('payBand');

    DetailRow? probationRow;
    if (probation != null) {
      final end = fmtDate(probation.at('probationEndDate'));
      final badge = switch (probation.s('kind')) {
        'ON_STIPEND' when probation.sn('probationEndDate') != null => TsBadge('Stipend until $end', tone: BadgeTone.amber),
        'REGULAR_AUTO_TRANSITIONED' => TsBadge('Regular Pay — probation ended $end', tone: BadgeTone.green),
        'REGULAR_OVERRIDE_ACTIVE' =>
          TsBadge('Stipend continued — probation ended $end, manual override active', tone: BadgeTone.amber),
        _ => null,
      };
      if (badge != null) probationRow = DetailRow(label: 'Probation', child: _Wrapping(badge));
    }

    return TsCard(
      title: 'Profile',
      child: DetailList(rows: [
        DetailRow(
          label: 'Status',
          child: _Wrapping(TsBadge(status, tone: status == 'ACTIVE' ? BadgeTone.green : BadgeTone.slate)),
        ),
        e.sn('employeeCode') != null
            ? DetailRow(label: 'Employee Code', value: e.s('employeeCode'))
            : const DetailRow(label: 'Employee Code', child: Muted('Assigned when a Date of Birth is on record')),
        DetailRow(label: 'Blood Group', value: e.s('bloodGroup', '—')),
        DetailRow(label: 'Email', value: e.s('email')),
        DetailRow(label: 'Mobile Number', value: e.s('mobileNumber', '—')),
        DetailRow(label: 'Date of Joining', value: fmtDate(e.at('dateOfJoining'))),
        e.s('employmentType') == 'INTERN'
            ? DetailRow(
                label: 'Employment Type',
                child: _Wrapping(TsBadge(
                  e.sn('internshipEndDate') != null ? 'Intern — until ${fmtDate(e.at('internshipEndDate'))}' : 'Intern',
                  tone: BadgeTone.purple,
                )),
              )
            : const DetailRow(label: 'Employment Type', value: 'Permanent'),
        DetailRow(
          label: 'Pay Band',
          value: payBand != null ? '${payBand.s('name')} — ${rupee(payBand.at('annualCTC'))} CTC' : '— None —',
        ),
        if (probationRow != null) probationRow,
        manager != null
            ? DetailRow(
                label: 'Reporting Manager',
                child: TsLink(manager.s('name'), color: p.foreground, weight: FontWeight.w400,
                    onTap: () => context.push('/employees/${manager.s('id')}')),
              )
            : DetailRow(
                label: 'Reporting Manager',
                child: Text('Not linked — leave requests route straight to HR', style: tx(14, color: p.warning)),
              ),
        if (data.b('showRegularPayReviewWarning'))
          DetailRow(
            label: '',
            child: Text(
              "Now on regular pay — review this employee's Payroll Profile, PF/ESI/PT were previously set for a "
              "stipend-based ${data.s('regularPayReviewSubject')}.",
              style: tx(12, color: p.warning, height: 1.5),
            ),
          ),
        if (appointment != null)
          DetailRow(
            label: 'From Appointment',
            child: TsLink(appointment.s('memoNo', 'View letter'), color: p.foreground, weight: FontWeight.w400,
                onTap: () => context.push('/appointments/${appointment.s('id')}')),
          ),
      ]),
    );
  }
}

/// Lets a long badge wrap inside a detail row instead of overflowing.
class _Wrapping extends StatelessWidget {
  const _Wrapping(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: child);
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(this.b);
  final Json b;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final (label, icon, tone) = _balanceCards[b.s('key')]!;
    return TsCard(
      title: label,
      icon: icon,
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fmtNumber(b.at('balance')), style: tx(24, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
          const SizedBox(height: 2),
          Text(
            '${fmtNumber(b.at('entitlementToDate'))} entitled to date · ${fmtNumber(b.at('daysTaken'))} used or reserved',
            style: tx(12, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _PortalAccessCard extends StatelessWidget {
  const _PortalAccessCard({required this.id, required this.portal});
  final String id;
  final Json portal;

  @override
  Widget build(BuildContext context) {
    final invite = FormActionButton(
      label: 'Send Portal Invite',
      pendingLabel: 'Sending...',
      run: () => api.action('people.sendPortalInvite', args: [id]),
    );
    Widget child;
    if (portal.sn('userCreatedAt') != null) {
      child = Muted('Active since ${fmtDate(portal.at('userCreatedAt'))}.');
    } else if (portal.sn('inviteSentAt') != null) {
      child = Gap(
        gap: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Muted(
            'Invite sent ${fmtDate(portal.at('inviteSentAt'))}'
            '${portal.b('inviteExpired') ? ' (expired)' : ' — not yet accepted'}.',
          ),
          invite,
        ],
      );
    } else {
      child = Align(alignment: Alignment.centerLeft, child: invite);
    }
    return TsCard(title: 'Portal Access', child: child);
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({required this.id, required this.docs});
  final String id;
  final Json docs;

  DetailRow _row(BuildContext context, String label, Json doc, String kind) {
    final p = Ts.of(context);
    if (!doc.b('present')) return DetailRow(label: label, child: const _Wrapping(TsBadge('Not uploaded')));
    return DetailRow(
      label: label,
      child: Wrap(
        spacing: 12,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TsLink('View', weight: FontWeight.w600,
              onTap: () => openWebFile(context, '/api/files/onboarding-document/$id/$kind')),
          if (doc.sn('detail') != null) Text(doc.s('detail'), style: tx(14, color: p.muted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return TsCard(
      title: 'Documents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (docs.b('deferredNotSubmitted'))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                "This employee chose \"Do it Later\" during onboarding and hasn't finished uploading yet.",
                style: tx(12, color: p.warning, height: 1.5),
              ),
            ),
          DetailList(rows: [
            _row(context, 'Qualification Certificate', docs.m('qualification'), 'qualification'),
            _row(context, 'PAN Card', docs.m('pan'), 'pan'),
            _row(context, 'Aadhaar Card', docs.m('aadhaar'), 'aadhaar'),
            _row(context, 'Bank Statement', docs.m('bank'), 'bank'),
            if (docs.b('showInternshipCertificate'))
              DetailRow(
                label: 'Internship Completion Certificate',
                child: TsLink('View', weight: FontWeight.w600,
                    onTap: () => openWebFile(context, '/api/employees/$id/internship-certificate?download=1')),
              ),
          ]),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.id, required this.attendance});
  final String id;
  final Json attendance;

  @override
  Widget build(BuildContext context) {
    final shift = attendance.mN('shift');
    final locations = attendance.list<String>('locations');
    return TsCard(
      title: 'Attendance',
      child: DetailList(rows: [
        DetailRow(
          label: 'Shift',
          value: shift != null ? '${shift.s('name')} (${shift.s('startTime')}–${shift.s('endTime')})' : '— None —',
        ),
        DetailRow(label: 'Locations', value: locations.isNotEmpty ? locations.join(', ') : '— None —'),
        DetailRow(
          label: 'Face Enrollment',
          child: attendance.b('faceEnrolled')
              ? Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const TsBadge('Enrolled', tone: BadgeTone.green),
                    ActionButton(
                      label: 'Reset Enrollment',
                      variant: TsButtonVariant.secondary,
                      compact: true,
                      run: () => api.action('people.resetEmployeeEnrollment', fields: {'employeeId': id}),
                    ),
                  ],
                )
              : const _Wrapping(TsBadge('Not enrolled')),
        ),
      ]),
    );
  }
}

class _PriorLeaveRow extends StatefulWidget {
  const _PriorLeaveRow({required this.employeeId, required this.record});
  final String employeeId;
  final Json record;

  @override
  State<_PriorLeaveRow> createState() => _PriorLeaveRowState();
}

class _PriorLeaveRowState extends State<_PriorLeaveRow> {
  bool _pending = false;

  Future<void> _remove() async {
    setState(() => _pending = true);
    await runAction(
      context,
      () => api.action('people.deletePriorLeaveRecord', fields: {
        'id': widget.record.s('id'),
        'employeeId': widget.employeeId,
      }),
      toastErrors: true,
    );
    if (mounted) setState(() => _pending = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final r = widget.record;
    final note = r.sn('note');
    return TsPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: Ts.rXl,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${r.s('typeLabel')} — ${r.s('numDays')} day(s)${note != null ? ' ($note)' : ''}',
              style: tx(14, color: p.foreground),
            ),
          ),
          const SizedBox(width: 12),
          _pending
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.danger))
              : TsLink('Remove', size: 12, color: p.danger, onTap: _remove),
        ],
      ),
    );
  }
}

class _PriorLeaveForm extends StatefulWidget {
  const _PriorLeaveForm({required this.employeeId});
  final String employeeId;

  @override
  State<_PriorLeaveForm> createState() => _PriorLeaveFormState();
}

class _PriorLeaveFormState extends State<_PriorLeaveForm> {
  final _days = TextEditingController();
  final _note = TextEditingController();
  String _type = 'EARNED';
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _days.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('people.recordPriorLeaveUsage', args: [widget.employeeId], fields: {
        'type': _type,
        'numDays': _days.text,
        'note': _note.text,
      }),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      // The web form resets after a successful action.
      if (r.ok) {
        _type = 'EARNED';
        _days.clear();
        _note.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 12,
      children: [
        TsSelect<String>(
          label: 'Leave type',
          value: _type,
          options: _leaveTypes,
          onChanged: (v) => setState(() => _type = v ?? 'EARNED'),
        ),
        TsInput(
          controller: _days,
          label: 'Days already used',
          keyboardType: TextInputType.number,
          inputFormatters: TsInput.digitsOnly,
        ),
        TsInput(controller: _note, label: 'Note (optional)'),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton.secondary(
            label: 'Add',
            icon: LucideIcons.plus,
            pendingLabel: 'Adding...',
            pending: _pending,
            onPressed: _add,
          ),
        ),
        if (_error != null) StatusMessage.error(_error),
      ],
    );
  }
}
