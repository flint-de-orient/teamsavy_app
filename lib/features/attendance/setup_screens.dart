import 'package:flutter/services.dart';

import '../../widgets/ts.dart';
import 'widgets.dart';

const _decimalKeyboard = TextInputType.numberWithOptions(decimal: true, signed: true);
final _decimalOnly = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))];

/// Save + Activate/Deactivate + "Inactive" pill + red error: the action
/// row every inline editor on these pages shares.
class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.saving,
    required this.onSave,
    required this.isActive,
    required this.toggle,
    required this.error,
  });

  final bool saving;
  final VoidCallback onSave;
  final bool isActive;
  final Future<ActionResult> Function() toggle;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TsButton.secondary(label: 'Save', pendingLabel: 'Saving...', pending: saving, compact: true, onPressed: onSave),
            ActionButton(
              label: isActive ? 'Deactivate' : 'Activate',
              variant: TsButtonVariant.secondary,
              compact: true,
              run: toggle,
            ),
            if (!isActive) const TsPill('Inactive'),
          ],
        ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusMessage.error(error)),
      ],
    );
  }
}

/// A titled card for the add forms ("Add Location" etc.).
class _AddCard extends StatelessWidget {
  const _AddCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return TsCard(
      child: Gap(gap: 14, children: children),
    );
  }
}

// ---------------------------------------------------------------------------
// /locations

/// app/(app)/locations/page.tsx + location-forms.tsx.
class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  static const _header = PageHeader(
    title: 'Locations',
    description: 'Offices and sites used for attendance geofencing. Employees are assigned one or more of these.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/locations',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        for (final l in data.l('locations')) _LocationRow(key: ValueKey(l.s('id')), location: l),
        const _AddLocationForm(),
      ],
    );
  }
}

class _LocationFields {
  _LocationFields({String name = '', String address = '', String lat = '', String lng = '', String radius = '200'})
      : name = TextEditingController(text: name),
        address = TextEditingController(text: address),
        latitude = TextEditingController(text: lat),
        longitude = TextEditingController(text: lng),
        radius = TextEditingController(text: radius);

  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController latitude;
  final TextEditingController longitude;
  final TextEditingController radius;

  Map<String, Object?> get fields => {
        'name': name.text,
        'address': address.text,
        'latitude': latitude.text,
        'longitude': longitude.text,
        'radiusMeters': radius.text,
      };

  List<Widget> build({bool placeholders = false}) => [
        TsInput(controller: name, label: 'Name', placeholder: placeholders ? 'Head Office' : null),
        TsInput(controller: address, label: 'Address', placeholder: placeholders ? 'Street, City' : null),
        Row(
          children: [
            Expanded(
              child: TsInput(
                controller: latitude,
                label: 'Latitude',
                keyboardType: _decimalKeyboard,
                inputFormatters: _decimalOnly,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TsInput(
                controller: longitude,
                label: 'Longitude',
                keyboardType: _decimalKeyboard,
                inputFormatters: _decimalOnly,
              ),
            ),
          ],
        ),
        TsInput(controller: radius, label: 'Radius (m)', keyboardType: TextInputType.number, inputFormatters: TsInput.digitsOnly),
      ];

  void dispose() {
    for (final c in [name, address, latitude, longitude, radius]) {
      c.dispose();
    }
  }
}

class _LocationRow extends StatefulWidget {
  const _LocationRow({super.key, required this.location});
  final Json location;

  @override
  State<_LocationRow> createState() => _LocationRowState();
}

class _LocationRowState extends State<_LocationRow> {
  late final _f = _LocationFields(
    name: widget.location.s('name'),
    address: widget.location.s('address'),
    lat: widget.location.s('latitude'),
    lng: widget.location.s('longitude'),
    radius: widget.location.s('radiusMeters'),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('attendance.updateLocation', fields: {'id': widget.location.s('id'), ..._f.fields}),
      successToast: 'Saved.',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.location;
    return TsCard(
      icon: LucideIcons.mapPin,
      title: l.s('name'),
      description: l.s('address'),
      child: Gap(
        gap: 14,
        children: [
          ..._f.build(),
          _RowActions(
            saving: _saving,
            onSave: _save,
            isActive: l.b('isActive'),
            error: _error,
            toggle: () => api.action(
              'attendance.setLocationActive',
              fields: {'id': l.s('id'), 'isActive': (!l.b('isActive')).toString()},
            ),
          ),
        ],
      ),
    );
  }
}

class _AddLocationForm extends StatefulWidget {
  const _AddLocationForm();

  @override
  State<_AddLocationForm> createState() => _AddLocationFormState();
}

class _AddLocationFormState extends State<_AddLocationForm> {
  var _f = _LocationFields();
  bool _pending = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  // Standing at the site is the easiest way to get its coordinates.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final fix = await requestLocationFix();
    if (!mounted) return;
    setState(() {
      _locating = false;
      final pos = fix.position;
      if (pos != null) {
        _f.latitude.text = pos.latitude.toStringAsFixed(6);
        _f.longitude.text = pos.longitude.toStringAsFixed(6);
      } else {
        _error = fix.error;
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(context, () => api.action('attendance.addLocation', fields: _f.fields), successToast: 'Location added.');
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      if (r.ok) {
        _f.dispose();
        _f = _LocationFields();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AddCard(
      children: [
        ..._f.build(placeholders: true),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton.ghost(
            label: 'Use my current location',
            pendingLabel: 'Getting your location…',
            pending: _locating,
            icon: LucideIcons.locateFixed,
            compact: true,
            onPressed: _useCurrentLocation,
          ),
        ),
        if (_error != null) StatusMessage.error(_error),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(label: 'Add Location', pendingLabel: 'Adding...', pending: _pending, onPressed: _submit),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// /shifts

/// app/(app)/shifts/page.tsx + shift-forms.tsx.
class ShiftsScreen extends StatelessWidget {
  const ShiftsScreen({super.key});

  static const _header = PageHeader(
    title: 'Shifts',
    description: 'Working hours used to compute late arrival and early departure. Each employee gets one shift.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/shifts',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        for (final s in data.l('shifts')) _ShiftEditor(key: ValueKey(s.s('id')), shift: s),
        const _ShiftEditor(key: ValueKey('new-shift')),
      ],
    );
  }
}

/// One shift row, or the add form when [shift] is null.
class _ShiftEditor extends StatefulWidget {
  const _ShiftEditor({super.key, this.shift});
  final Json? shift;

  @override
  State<_ShiftEditor> createState() => _ShiftEditorState();
}

class _ShiftEditorState extends State<_ShiftEditor> {
  late final _name = TextEditingController(text: widget.shift?.s('name') ?? '');
  late String? _start = widget.shift?.sn('startTime');
  late String? _end = widget.shift?.sn('endTime');
  late bool _crosses = widget.shift?.b('crossesMidnight') ?? false;
  bool _pending = false;
  String? _error;

  bool get _isNew => widget.shift == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final fields = <String, Object?>{
      if (!_isNew) 'id': widget.shift!.s('id'),
      'name': _name.text,
      'startTime': _start ?? '',
      'endTime': _end ?? '',
      if (_crosses) 'crossesMidnight': 'on',
    };
    final r = await runAction(
      context,
      () => api.action(_isNew ? 'attendance.addShift' : 'attendance.updateShift', fields: fields),
      successToast: _isNew ? 'Shift added.' : 'Saved.',
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      if (r.ok && _isNew) {
        _name.clear();
        _start = null;
        _end = null;
        _crosses = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shift;
    final fields = [
      TsInput(controller: _name, label: 'Name', placeholder: _isNew ? 'General' : null),
      Row(
        children: [
          Expanded(child: TsTimeField(label: 'Start', value: _start, onChanged: (v) => setState(() => _start = v))),
          const SizedBox(width: 12),
          Expanded(child: TsTimeField(label: 'End', value: _end, onChanged: (v) => setState(() => _end = v))),
        ],
      ),
      TsCheckbox(label: 'Crosses midnight', value: _crosses, onChanged: (v) => setState(() => _crosses = v)),
    ];
    if (s == null) {
      return _AddCard(
        children: [
          ...fields,
          if (_error != null) StatusMessage.error(_error),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(label: 'Add Shift', pendingLabel: 'Adding...', pending: _pending, onPressed: _submit),
          ),
        ],
      );
    }
    return TsCard(
      icon: LucideIcons.clock,
      title: s.s('name'),
      description: '${s.s('startTime')}–${s.s('endTime')}',
      child: Gap(
        gap: 14,
        children: [
          ...fields,
          _RowActions(
            saving: _pending,
            onSave: _submit,
            isActive: s.b('isActive'),
            error: _error,
            toggle: () => api.action(
              'attendance.setShiftActive',
              fields: {'id': s.s('id'), 'isActive': (!s.b('isActive')).toString()},
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// /devices

BadgeTone _connectionTone(String status) => switch (status) {
      'ACTIVE' => BadgeTone.green,
      'ERROR' => BadgeTone.red,
      _ => BadgeTone.slate,
    };

/// app/(app)/devices/page.tsx + device-connection-forms.tsx + device-forms.tsx.
class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  static const _title = 'Devices';
  static const _description =
      'Biometric, face-recognition, and NFC devices, and the vendor accounts that sync punches from them.';

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/devices',
      header: const PageHeader(title: _title, description: _description),
      builder: (context, data, reload) {
        final unmatched = data.i('unmatchedCount');
        final connections = data.l('connections');
        final locations = data.l('locations');
        final canManage = data.b('canManageConnections');
        return [
          PageHeader(
            title: _title,
            description: _description,
            actions: [
              if (unmatched > 0)
                TsLink(
                  '$unmatched unmatched punch${unmatched == 1 ? '' : 'es'} →',
                  weight: FontWeight.w600,
                  onTap: () => context.push('/devices/unmatched'),
                ),
            ],
          ),
          const SectionTitle('Vendor Connections', top: 0),
          if (!canManage)
            TsCard(
              child: Gap(
                gap: 12,
                children: [
                  if (connections.isEmpty) const Muted('No vendor connections set up yet.'),
                  for (final c in connections)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.s('vendorLabel'),
                            style: tx(14, weight: FontWeight.w600, color: Ts.of(context).foreground),
                          ),
                        ),
                        TsBadge(c.s('status'), tone: _connectionTone(c.s('status'))),
                      ],
                    ),
                  const Muted('Contact your tenant admin to manage vendor connections.', size: 12),
                ],
              ),
            )
          else ...[
            const Muted(
              "Punches sync automatically every few minutes. Credentials are per vendor account, not per physical device - punches from this connection aren't attributed to a specific machine unless the vendor supports it.",
              size: 12,
            ),
            for (final c in connections) _ConnectionRow(key: ValueKey(c.s('id')), connection: c),
            const _AddConnectionForm(),
          ],
          const SectionTitle('Devices', top: 16),
          if (locations.isEmpty)
            const Muted('Add a location first (Settings → Locations) before registering a device.')
          else ...[
            for (final d in data.l('devices'))
              _DeviceEditor(
                key: ValueKey(d.s('id')),
                device: d,
                types: data.l('deviceTypes'),
                locations: locations,
                connections: connections,
              ),
            _DeviceEditor(
              key: const ValueKey('new-device'),
              types: data.l('deviceTypes'),
              locations: locations,
              connections: connections,
            ),
          ],
        ];
      },
    );
  }
}

class _ConnectionRow extends StatefulWidget {
  const _ConnectionRow({super.key, required this.connection});
  final Json connection;

  @override
  State<_ConnectionRow> createState() => _ConnectionRowState();
}

class _ConnectionRowState extends State<_ConnectionRow> {
  final _corporateId = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _syncing = false;
  String? _syncError;
  String? _syncMessage;

  @override
  void dispose() {
    _corporateId.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('attendance.updateDeviceConnection', fields: {
        'id': widget.connection.s('id'),
        'corporateId': _corporateId.text,
        'username': _username.text,
        'password': _password.text,
      }),
      successToast: 'Saved.',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = r.error;
    });
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncError = null;
      _syncMessage = null;
    });
    final r = await api.action('attendance.syncDeviceConnectionNow', fields: {'id': widget.connection.s('id')});
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncError = r.error;
      _syncMessage = r.ok ? r.message : null;
    });
    // Either way the connection's lastSyncAt / lastSyncError changed.
    refreshBus.bump();
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final c = widget.connection;
    final active = c.s('status') == 'ACTIVE';
    return TsCard(
      icon: LucideIcons.cpu,
      title: c.s('vendorLabel'),
      action: TsBadge(c.s('status'), tone: _connectionTone(c.s('status'))),
      child: Gap(
        gap: 14,
        children: [
          if (c.at('lastSyncAt') != null || c.sn('lastSyncError') != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.at('lastSyncAt') != null)
                  Text('Last synced ${fmtDateTime(c.at('lastSyncAt'))}', style: tx(12, color: p.muted)),
                if (c.sn('lastSyncError') != null)
                  Text('Last error: ${c.s('lastSyncError')}', style: tx(12, color: p.danger)),
              ],
            ),
          TsInput(controller: _corporateId, label: 'Corporate ID', placeholder: 'Re-enter to change'),
          TsInput(controller: _username, label: 'Username', placeholder: 'Re-enter to change'),
          TsInput(
            controller: _password,
            label: 'Password',
            obscure: true,
            placeholder: 'Leave blank to keep the current password',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton.secondary(label: 'Save', pendingLabel: 'Saving...', pending: _saving, compact: true, onPressed: _save),
          ),
          if (_error != null) StatusMessage.error(_error),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TsButton.secondary(
                label: 'Sync Now',
                pendingLabel: 'Syncing...',
                pending: _syncing,
                compact: true,
                icon: LucideIcons.refreshCw,
                onPressed: _sync,
              ),
              ActionButton(
                label: active ? 'Pause' : 'Resume',
                variant: TsButtonVariant.secondary,
                compact: true,
                run: () => api.action(
                  'attendance.setDeviceConnectionStatus',
                  fields: {'id': c.s('id'), 'status': active ? 'PAUSED' : 'ACTIVE'},
                ),
              ),
            ],
          ),
          if (_syncError != null) StatusMessage.error(_syncError),
          if (_syncMessage != null) StatusMessage.success(_syncMessage),
        ],
      ),
    );
  }
}

class _AddConnectionForm extends StatefulWidget {
  const _AddConnectionForm();

  @override
  State<_AddConnectionForm> createState() => _AddConnectionFormState();
}

class _AddConnectionFormState extends State<_AddConnectionForm> {
  final _corporateId = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _corporateId.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('attendance.addDeviceConnection', fields: {
        'corporateId': _corporateId.text,
        'username': _username.text,
        'password': _password.text,
      }),
      successToast: 'Connection added.',
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
    if (r.ok) {
      _corporateId.clear();
      _username.clear();
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AddCard(
      children: [
        TsInput(controller: _corporateId, label: 'Corporate ID'),
        TsInput(controller: _username, label: 'Username'),
        TsInput(controller: _password, label: 'Password', obscure: true),
        if (_error != null) StatusMessage.error(_error),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(
            label: 'Add eTimeOffice Connection',
            pendingLabel: 'Adding...',
            pending: _pending,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

/// One device row, or the add form when [device] is null.
class _DeviceEditor extends StatefulWidget {
  const _DeviceEditor({
    super.key,
    this.device,
    required this.types,
    required this.locations,
    required this.connections,
  });

  final Json? device;
  final List<Json> types;
  final List<Json> locations;
  final List<Json> connections;

  @override
  State<_DeviceEditor> createState() => _DeviceEditorState();
}

class _DeviceEditorState extends State<_DeviceEditor> {
  late final _name = TextEditingController(text: widget.device?.s('name') ?? '');
  late String _type = widget.device?.s('type') ?? 'BIOMETRIC';
  late String? _locationId = widget.device?.sn('locationId');
  late String _connectionId = widget.device?.s('deviceConnectionId') ?? '';
  bool _pending = false;
  String? _error;

  bool get _isNew => widget.device == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final fields = <String, Object?>{
      if (!_isNew) 'id': widget.device!.s('id'),
      'vendor': widget.device?.s('vendor') ?? 'ETIMEOFFICE',
      'name': _name.text,
      'type': _type,
      'locationId': _locationId ?? '',
      'deviceConnectionId': _connectionId,
    };
    final r = await runAction(
      context,
      () => api.action(_isNew ? 'attendance.addDevice' : 'attendance.updateDevice', fields: fields),
      successToast: _isNew ? 'Device added.' : 'Saved.',
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      if (r.ok && _isNew) {
        _name.clear();
        _type = 'BIOMETRIC';
        _locationId = null;
        _connectionId = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final fields = [
      TsInput(controller: _name, label: 'Name', placeholder: _isNew ? 'Main Gate Biometric' : null),
      TsSelect<String>(
        label: 'Type',
        value: _type,
        options: [for (final t in widget.types) SelectOption(t.s('value'), t.s('label'))],
        onChanged: (v) => setState(() => _type = v ?? _type),
      ),
      TsSelect<String>(
        label: 'Location',
        value: _locationId,
        placeholder: '— Choose —',
        options: [for (final l in widget.locations) SelectOption(l.s('id'), l.s('name'))],
        onChanged: (v) => setState(() => _locationId = v),
      ),
      TsSelect<String>(
        label: 'Connection',
        value: _connectionId,
        options: [
          const SelectOption('', '— None —'),
          for (final c in widget.connections) SelectOption(c.s('id'), c.s('vendor')),
        ],
        onChanged: (v) => setState(() => _connectionId = v ?? ''),
      ),
    ];
    if (d == null) {
      return _AddCard(
        children: [
          ...fields,
          if (_error != null) StatusMessage.error(_error),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(label: 'Add Device', pendingLabel: 'Adding...', pending: _pending, onPressed: _submit),
          ),
        ],
      );
    }
    return TsCard(
      icon: LucideIcons.fingerprint,
      title: d.s('name'),
      child: Gap(
        gap: 14,
        children: [
          ...fields,
          _RowActions(
            saving: _pending,
            onSave: _submit,
            isActive: d.b('isActive'),
            error: _error,
            toggle: () => api.action(
              'attendance.setDeviceActive',
              fields: {'id': d.s('id'), 'isActive': (!d.b('isActive')).toString()},
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// /devices/unmatched

/// app/(app)/devices/unmatched/page.tsx.
class UnmatchedPunchesScreen extends StatelessWidget {
  const UnmatchedPunchesScreen({super.key});

  static const _header = PageHeader(
    title: 'Unmatched Punches',
    description:
        "Punches from a device code that isn't mapped to an employee yet. Mapping one backfills every punch with the same code.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/devices/unmatched',
      header: _header,
      builder: (context, data, reload) {
        final punches = data.l('punches');
        final employees = data.l('employees');
        return [
          _header,
          if (punches.isEmpty) const EmptyState('No unmatched punches.', icon: LucideIcons.fingerprint),
          for (final punch in punches)
            MobileCard(
              key: ValueKey(punch.s('id')),
              children: [
                MobileCardHeader(title: fmtDateTime(punch.at('punchAt'))),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Device Code', value: punch.s('unmatchedEmployeeCode')),
                  MobileCardRow(label: 'Vendor', value: punch.sn('vendor') ?? '—'),
                ]),
                MobileCardFooter(child: _MapPunchForm(punchEventId: punch.s('id'), employees: employees)),
              ],
            ),
        ];
      },
    );
  }
}

class _MapPunchForm extends StatefulWidget {
  const _MapPunchForm({required this.punchEventId, required this.employees});
  final String punchEventId;
  final List<Json> employees;

  @override
  State<_MapPunchForm> createState() => _MapPunchFormState();
}

class _MapPunchFormState extends State<_MapPunchForm> {
  String? _employeeId;
  bool _pending = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action(
        'attendance.mapUnmatchedPunch',
        fields: {'punchEventId': widget.punchEventId, 'employeeId': _employeeId ?? ''},
      ),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 12,
      children: [
        TsSelect<String>(
          label: 'Map to employee',
          value: _employeeId,
          placeholder: '— Choose —',
          options: [for (final e in widget.employees) SelectOption(e.s('id'), e.s('name'))],
          onChanged: (v) => setState(() => _employeeId = v),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton.secondary(label: 'Map', pendingLabel: 'Mapping...', pending: _pending, compact: true, onPressed: _submit),
        ),
        if (_error != null) StatusMessage.error(_error),
      ],
    );
  }
}
