import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/ts.dart';
import 'widgets.dart';

const _title = 'Punch In / Out';
const _description =
    'Uses your camera and location - a punch outside your assigned locations is still recorded but flagged for HR review.';
const _faceMismatch = "Face didn't match your enrollment photo. Try again or contact HR.";

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// app/(app)/attendance/punch/page.tsx + punch-client.tsx: one-time face
/// enrollment, then selfie + location punches. Unlike the web, every punch
/// takes a fresh location fix and the outcome stays on screen.
class PunchScreen extends StatelessWidget {
  const PunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/attendance/punch',
      header: const PageHeader(title: _title),
      builder: (context, data, reload) {
        if (!data.b('authorized')) {
          return [const PageHeader(title: _title), StatusMessage.error('You are not authorized to check in.')];
        }
        if (!data.b('hasEmployee')) {
          return [const PageHeader(title: _title), const Muted('No employee record is linked to your account.')];
        }
        final enrolled = data.b('isEnrolled');
        return [
          const PageHeader(title: _title, description: _description),
          if (enrolled) _TodayCard(data: data),
          if (enrolled)
            _PunchFlow(key: const ValueKey('punch-flow'), locations: data.l('locations'))
          else
            const _EnrollmentFlow(key: ValueKey('enrollment-flow')),
        ];
      },
    );
  }
}

/// Opens the front camera for one still. `photo` is null when the user
/// backed out; `error` carries the web's camera error text.
Future<({XFile? photo, String? error})> _captureSelfie() async {
  try {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1280,
      imageQuality: 85,
    );
    return (photo: photo, error: null);
  } on PlatformException catch (e) {
    return (
      photo: null,
      error: e.code == 'camera_access_denied'
          ? 'Camera permission was denied. Allow camera access to check in.'
          : "Couldn't access a camera on this device.",
    );
  } catch (_) {
    return (photo: null, error: "Couldn't access a camera on this device.");
  }
}

UploadFile _upload(XFile photo) => UploadFile(photo.path, filename: 'selfie.jpg', contentType: 'image/jpeg');

// ---------------------------------------------------------------------------
// Enrollment (Mode A)

class _EnrollmentFlow extends StatefulWidget {
  const _EnrollmentFlow({super.key});

  @override
  State<_EnrollmentFlow> createState() => _EnrollmentFlowState();
}

class _EnrollmentFlowState extends State<_EnrollmentFlow> {
  XFile? _photo;
  bool _capturing = false;
  String? _cameraError;
  bool _saving = false;
  String? _error;

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _cameraError = null;
      _error = null;
    });
    final shot = await _captureSelfie();
    if (!mounted) return;
    setState(() {
      _capturing = false;
      _cameraError = shot.error;
      if (shot.photo != null) _photo = shot.photo;
    });
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await api.action('attendance.enrollFace', files: {'photo': _upload(photo)});
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = r.error;
    });
    if (r.ok) {
      // The page switches to punch mode on reload, so the web's success
      // line would vanish with it - it goes in a toast instead.
      HapticFeedback.mediumImpact();
      toast(context, r.message ?? 'Enrollment photo saved. You can now punch in.');
      refreshBus.bump();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 16,
      children: [
        const Muted(
          "Before you can punch in from your phone or a shared computer, capture a reference photo once. Every future check-in selfie is compared against it - if a punch is rejected because the face doesn't match, contact HR to re-enroll.",
        ),
        TsCard(
          padding: const EdgeInsets.all(14),
          child: Gap(
            gap: 14,
            children: [
              _SelfieCard(
                photo: _photo,
                capturing: _capturing,
                error: _cameraError,
                captureLabel: 'Capture Enrollment Photo',
                onCapture: _saving ? null : _capture,
              ),
              if (_photo != null)
                TsButton(
                  label: 'Save Enrollment Photo',
                  pendingLabel: 'Saving...',
                  pending: _saving,
                  icon: LucideIcons.userCheck,
                  expand: true,
                  onPressed: _save,
                ),
              if (_error != null) StatusMessage.error(_error),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Punch (Mode B)

enum _LocState { idle, requesting, ready, error }

enum _Outcome { success, flagged, faceMismatch, error }

class _PunchResult {
  _PunchResult(this.kind, this.message, this.direction) : at = DateTime.now();
  final _Outcome kind;
  final String message;
  final String direction;
  final DateTime at;
}

class _PunchFlow extends StatefulWidget {
  const _PunchFlow({super.key, required this.locations});
  final List<Json> locations;

  @override
  State<_PunchFlow> createState() => _PunchFlowState();
}

class _PunchFlowState extends State<_PunchFlow> {
  XFile? _photo;
  bool _capturing = false;
  String? _cameraError;

  _LocState _loc = _LocState.idle;
  Position? _position;
  DateTime? _fixAt;
  String? _locError;
  String? _locSettings;

  /// 'IN' / 'OUT' while that punch is in flight.
  String? _pending;
  _PunchResult? _result;

  bool get _hasFreshFix =>
      _position != null && _fixAt != null && DateTime.now().difference(_fixAt!) < const Duration(seconds: 30);

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _cameraError = null;
    });
    final shot = await _captureSelfie();
    if (!mounted) return;
    setState(() {
      _capturing = false;
      _cameraError = shot.error;
      if (shot.photo != null) {
        _photo = shot.photo;
        _result = null;
      }
    });
    if (shot.photo != null && !_hasFreshFix) await _locate();
  }

  Future<Position?> _locate() async {
    setState(() {
      _loc = _LocState.requesting;
      _locError = null;
      _locSettings = null;
    });
    final fix = await requestLocationFix();
    if (!mounted) return null;
    setState(() {
      if (fix.position != null) {
        _loc = _LocState.ready;
        _position = fix.position;
        _fixAt = DateTime.now();
      } else {
        _loc = _LocState.error;
        _position = null;
        _fixAt = null;
        _locError = fix.error;
        _locSettings = fix.settings;
      }
    });
    return fix.position;
  }

  Future<void> _punch(String direction) async {
    final photo = _photo;
    if (photo == null || _pending != null) return;
    setState(() {
      _pending = direction;
      _result = null;
    });
    // Never reuse an old fix: anything older than 30 seconds is re-taken.
    final position = _hasFreshFix ? _position : await _locate();
    if (!mounted) return;
    if (position == null) {
      setState(() => _pending = null);
      return;
    }
    final r = await api.action(
      'attendance.punchInOut',
      args: [direction],
      fields: {'latitude': position.latitude, 'longitude': position.longitude},
      files: {'photo': _upload(photo)},
    );
    if (!mounted) return;
    if (r.ok) {
      HapticFeedback.mediumImpact();
      refreshBus.bump();
      final message = r.message ?? (direction == 'IN' ? 'Punched in successfully.' : 'Punched out successfully.');
      setState(() {
        _pending = null;
        _result = _PunchResult(
          message.contains('flagged for HR review') ? _Outcome.flagged : _Outcome.success,
          message,
          direction,
        );
        // Back to a fresh camera, like the web - the next punch of the day
        // needs its own selfie and its own location.
        _photo = null;
        _position = null;
        _fixAt = null;
        _loc = _LocState.idle;
      });
      return;
    }
    final error = r.error!;
    // HR reset the enrollment while this page was open: reload into Mode A.
    if (error.startsWith('Complete face enrollment first')) refreshBus.bump();
    HapticFeedback.heavyImpact();
    setState(() {
      _pending = null;
      if (error == _faceMismatch) {
        _result = _PunchResult(_Outcome.faceMismatch, error, direction);
        _photo = null;
      } else {
        _result = _PunchResult(_Outcome.error, error, direction);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _pending != null;
    final canPunch = _photo != null && _loc == _LocState.ready && !_capturing;
    return Gap(
      gap: 16,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _result == null
              ? const SizedBox.shrink()
              : _ResultBanner(
                  key: ValueKey(_result),
                  result: _result!,
                  onRetake: busy ? null : _capture,
                  onDismiss: () => setState(() => _result = null),
                ),
        ),
        TsCard(
          padding: const EdgeInsets.all(14),
          child: Gap(
            gap: 14,
            children: [
              _SelfieCard(
                photo: _photo,
                capturing: _capturing,
                error: _cameraError,
                captureLabel: 'Capture Selfie',
                onCapture: busy ? null : _capture,
              ),
              if (_photo != null && _loc != _LocState.idle)
                _LocationPanel(
                  state: _loc,
                  position: _position,
                  error: _locError,
                  settings: _locSettings,
                  locations: widget.locations,
                  onRetry: busy ? null : _locate,
                ),
              Row(
                children: [
                  Expanded(
                    child: _PunchButton(
                      label: 'Punch In',
                      pendingLabel: 'Punching in...',
                      icon: LucideIcons.logIn,
                      primary: true,
                      pending: _pending == 'IN',
                      onPressed: canPunch && !busy ? () => _punch('IN') : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PunchButton(
                      label: 'Punch Out',
                      pendingLabel: 'Punching out...',
                      icon: LucideIcons.logOut,
                      primary: false,
                      pending: _pending == 'OUT',
                      onPressed: canPunch && !busy ? () => _punch('OUT') : null,
                    ),
                  ),
                ],
              ),
              if (_photo == null) const Muted('Capture a selfie to punch in/out.', size: 12, align: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces

/// Today at a glance: a live IST clock, the shift, today's status and the
/// punches recorded so far.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final today = data.mN('today');
    final shift = data.mN('shift');
    final punches = data.l('todayPunches');
    final now = toIST(DateTime.now());

    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tx(12, color: p.muted)),
              const SizedBox(height: 2),
              Text(value, style: tx(15, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        gradient: p.gradientSoft,
        borderRadius: BorderRadius.circular(Ts.r3xl),
        boxShadow: p.shadowCard,
      ),
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: p.dark ? 0.55 : 0.6),
          borderRadius: BorderRadius.circular(Ts.r3xl - 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LiveClock(),
                      const SizedBox(height: 2),
                      Text(
                        '${_weekdays[now.weekday - 1]}, ${now.day} ${monthName(now.month)} ${now.year}',
                        style: tx(13, color: p.muted),
                      ),
                    ],
                  ),
                ),
                if (today != null) DayStatusBadge(today),
              ],
            ),
            if (shift != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(LucideIcons.clock, size: 14, color: p.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${shift.s('name')} (${shift.s('startTime')}–${shift.s('endTime')})',
                      style: tx(13, weight: FontWeight.w500, color: p.secondary),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Container(height: 1, color: p.border.withValues(alpha: 0.8)),
            const SizedBox(height: 14),
            Row(
              children: [
                stat('First Punch', fmtTime(today?.at('firstPunchAt'), seconds: false)),
                stat('Last Punch', fmtTime(today?.at('lastPunchAt'), seconds: false)),
                stat('Worked', workedTime(today?.at('workedMinutes'))),
              ],
            ),
            if (today != null && today.l('flags').isNotEmpty) ...[
              const SizedBox(height: 12),
              DayFlags(today.l('flags')),
            ],
            if (punches.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final punch in punches) _PunchChip(punch)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PunchChip extends StatelessWidget {
  const _PunchChip(this.punch);
  final Json punch;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final inside = punch.at('withinGeofence');
    final dot = inside == true ? p.success : (inside == false ? p.danger : p.muted);
    return Tooltip(
      message: inside == null ? punch.s('source') : (inside == true ? 'Inside' : 'Outside'),
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(punch.s('direction'), style: tx(12, weight: FontWeight.w700, color: p.foreground)),
            const SizedBox(width: 5),
            Text(fmtTime(punch.at('punchAt'), seconds: false), style: tx(12, color: p.muted)),
          ],
        ),
      ),
    );
  }
}

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final t = toIST(DateTime.now());
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$h:${t.minute.toString().padLeft(2, '0')}',
            style: tx(34, weight: FontWeight.w700, color: p.foreground, height: 1.1, tracking: -0.03),
          ),
          TextSpan(
            text: ':${t.second.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}',
            style: tx(15, weight: FontWeight.w600, color: p.muted),
          ),
        ],
      ),
    );
  }
}

/// The big selfie frame: an oval face guide until a photo is taken, then
/// the photo itself with a Retake button over it.
class _SelfieCard extends StatelessWidget {
  const _SelfieCard({
    required this.photo,
    required this.capturing,
    required this.error,
    required this.captureLabel,
    required this.onCapture,
  });

  final XFile? photo;
  final bool capturing;
  final String? error;
  final String captureLabel;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final radius = BorderRadius.circular(20);
    final photo = this.photo;

    Widget placeholder() => DecoratedBox(
          decoration: BoxDecoration(gradient: p.gradientSoft),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 150,
                  height: 196,
                  decoration: ShapeDecoration(
                    color: Colors.white.withValues(alpha: p.dark ? 0.06 : 0.28),
                    shape: OvalBorder(
                      side: BorderSide(color: Colors.white.withValues(alpha: p.dark ? 0.35 : 0.9), width: 2),
                    ),
                  ),
                  child: Icon(
                    error != null ? LucideIcons.cameraOff : LucideIcons.scanFace,
                    size: 52,
                    color: (error != null ? p.danger : p.primary).withValues(alpha: 0.55),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(error!, textAlign: TextAlign.center, style: tx(14, weight: FontWeight.w500, color: p.danger)),
                  ),
                ],
                const SizedBox(height: 64),
              ],
            ),
          ),
        );

    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null) Image.file(File(photo.path), fit: BoxFit.cover) else placeholder(),
            if (capturing)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                alignment: Alignment.center,
                child: Text('Requesting camera access…', style: tx(14, color: Colors.white)),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Center(
                child: photo != null
                    ? _GlassButton(label: 'Retake', icon: LucideIcons.refreshCw, onTap: onCapture)
                    : error != null
                        ? TsButton.secondary(label: 'Try Again', icon: LucideIcons.refreshCw, onPressed: onCapture)
                        : TsButton(label: captureLabel, icon: LucideIcons.camera, onPressed: onCapture),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(label, style: tx(14, weight: FontWeight.w600, color: Colors.white, tracking: kTight)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The location chip: requesting / failed (web texts + Try Again) / the
/// captured coordinates and where they fall against the assigned
/// locations (the same haversine check the server runs).
class _LocationPanel extends StatelessWidget {
  const _LocationPanel({
    required this.state,
    required this.position,
    required this.error,
    required this.settings,
    required this.locations,
    required this.onRetry,
  });

  final _LocState state;
  final Position? position;
  final String? error;
  final String? settings;
  final List<Json> locations;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    if (state == _LocState.requesting) {
      return _chip(
        p,
        icon: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.accentViolet)),
        tint: p.primaryLight,
        child: Text('Getting your location…', style: tx(14, color: p.muted)),
      );
    }
    if (state == _LocState.error || position == null) {
      return _chip(
        p,
        icon: Icon(LucideIcons.mapPinOff, size: 16, color: p.danger),
        tint: p.dangerLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error ?? kLocationFailed, style: tx(14, color: p.danger)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TsButton.secondary(label: 'Try Again', compact: true, onPressed: onRetry),
                if (settings != null)
                  TsButton.ghost(
                    label: 'Open Settings',
                    compact: true,
                    onPressed: () => openLocationSettingsFor(settings),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final pos = position!;
    Json? nearest;
    double nearestDistance = double.infinity;
    for (final l in locations) {
      final d = haversineMeters(pos.latitude, pos.longitude, l.d('latitude'), l.d('longitude'));
      if (d < nearestDistance) {
        nearestDistance = d;
        nearest = l;
      }
    }
    final inside = nearest != null && nearestDistance <= nearest.d('radiusMeters');
    final tone = inside ? p.success : p.warning;
    final where = nearest == null
        ? 'No location assigned - this punch will be flagged for HR review.'
        : inside
            ? 'Inside ${nearest.s('name')} · ${distanceLabel(nearestDistance)} from centre'
            : 'Outside ${nearest.s('name')} · ${distanceLabel(nearestDistance)} away';

    return _chip(
      p,
      icon: Icon(inside ? LucideIcons.mapPin : LucideIcons.mapPinOff, size: 16, color: tone),
      tint: inside ? p.successLight : p.warningLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(where, style: tx(14, weight: FontWeight.w600, color: p.foreground)),
          const SizedBox(height: 2),
          Text(
            'Location captured (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}) · ±${pos.accuracy.round()} m',
            style: tx(12, color: p.muted),
          ),
        ],
      ),
    );
  }

  Widget _chip(TsPalette p, {required Widget icon, required Color tint, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Ts.r2xl),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(Ts.rXl)),
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 6), child: child)),
        ],
      ),
    );
  }
}

/// A tall pill: Punch In is the gradient primary, Punch Out the bordered
/// secondary - the web's two buttons, sized for a thumb.
class _PunchButton extends StatelessWidget {
  const _PunchButton({
    required this.label,
    required this.pendingLabel,
    required this.icon,
    required this.primary,
    required this.pending,
    required this.onPressed,
  });

  final String label;
  final String pendingLabel;
  final IconData icon;
  final bool primary;
  final bool pending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final fg = primary ? p.primaryForeground : p.foreground;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: pending ? pendingLabel : label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled || pending ? 1 : 0.45,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: primary ? p.gradientPrimary : null,
              color: primary ? null : p.surface,
              borderRadius: BorderRadius.circular(999),
              border: primary ? null : Border.all(color: p.border),
              boxShadow: primary && enabled ? p.shadowButton : p.shadowXs,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pending)
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                  else
                    Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                  Text(
                    pending ? pendingLabel : label,
                    style: tx(16, weight: FontWeight.w700, color: fg, tracking: kTight),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The punch outcome: green (inside), amber (recorded but flagged),
/// red with a retake for a face mismatch, red for anything else.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({super.key, required this.result, required this.onRetake, required this.onDismiss});
  final _PunchResult result;
  final VoidCallback? onRetake;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final verb = result.direction == 'IN' ? 'in' : 'out';
    final (Color bg, Color fg, IconData icon, String title) = switch (result.kind) {
      _Outcome.success => (p.successLight, p.success, LucideIcons.circleCheck, 'Punched $verb'),
      _Outcome.flagged => (p.warningLight, p.warning, LucideIcons.mapPinOff, 'Punched $verb · flagged for review'),
      _Outcome.faceMismatch => (p.dangerLight, p.danger, LucideIcons.scanFace, "Face didn't match"),
      _Outcome.error => (p.dangerLight, p.danger, LucideIcons.circleAlert, "Couldn't punch $verb"),
    };
    final recorded = result.kind == _Outcome.success || result.kind == _Outcome.flagged;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Ts.r3xl),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
        boxShadow: p.shadowCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: p.dark ? p.background : Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tx(16, weight: FontWeight.w700, color: p.dark ? fg : p.foreground, tracking: kTight)),
                const SizedBox(height: 4),
                Text(result.message, style: tx(14, color: p.dark ? p.foreground : p.secondary, height: 1.5)),
                if (recorded) ...[
                  const SizedBox(height: 6),
                  Text(fmtDateTime(result.at), style: tx(12, color: p.muted)),
                ],
                if (result.kind == _Outcome.faceMismatch) ...[
                  const SizedBox(height: 12),
                  TsButton(label: 'Capture Selfie', icon: LucideIcons.camera, compact: true, onPressed: onRetake),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(LucideIcons.x, size: 18, color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}
