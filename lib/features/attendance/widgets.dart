import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../widgets/ts.dart';

/// The day status badge: `status.replace("_", " ")` in the web's tone map
/// (both computed by the API).
class DayStatusBadge extends StatelessWidget {
  const DayStatusBadge(this.day, {super.key});
  final Json day;

  @override
  Widget build(BuildContext context) =>
      TsBadge(day.s('statusLabel'), tone: badgeToneFrom(day.sn('statusTone')));
}

/// Late / Early Out / Missing Punch Out / Geofence / Leave Deducted. The
/// web's `title` tooltip ("Leave Deducted") shows on long-press.
class DayFlags extends StatelessWidget {
  const DayFlags(this.flags, {super.key});
  final List<Json> flags;

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final f in flags)
          f.sn('title') == null
              ? TsBadge(f.s('label'), tone: badgeToneFrom(f.sn('tone')))
              : Tooltip(
                  message: f.s('title'),
                  triggerMode: TooltipTriggerMode.tap,
                  child: TsBadge(f.s('label'), tone: badgeToneFrom(f.sn('tone'))),
                ),
      ],
    );
  }
}

/// One AttendanceDay as the web's MobileCard renders it: status badge,
/// First / Last Punch (a lone punch only under First), worked time, flag
/// badges, and a footer (Request a fix / OverrideCell).
class AttendanceDayCard extends StatelessWidget {
  const AttendanceDayCard({super.key, required this.title, required this.day, this.onTap, this.footer});
  final String title;
  final Json day;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final flags = day.l('flags');
    return MobileCard(
      onTap: onTap,
      children: [
        MobileCardHeader(title: title, action: DayStatusBadge(day)),
        MobileCardRows(rows: [
          MobileCardRow(label: 'First Punch', value: fmtTime(day.at('firstPunchAt'))),
          MobileCardRow(label: 'Last Punch', value: fmtTime(day.at('lastPunchAt'))),
          MobileCardRow(label: 'Worked', value: workedTime(day.at('workedMinutes'))),
        ]),
        if (flags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: DayFlags(flags)),
        if (footer != null) MobileCardFooter(child: footer!),
      ],
    );
  }
}

/// app/(app)/attendance/override-cell.tsx: an "Override" link to the
/// override form, or the purple "Overridden" badge with a "Clear" button.
class OverrideCell extends StatefulWidget {
  const OverrideCell({super.key, required this.day, this.returnTo});
  final Json day;

  /// Where the override form goes back to (defaults to the daily grid).
  final String? returnTo;

  @override
  State<OverrideCell> createState() => _OverrideCellState();
}

class _OverrideCellState extends State<OverrideCell> {
  bool _pending = false;
  String? _error;

  Future<void> _clear() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('attendance.clearAttendanceOverride', args: [widget.day.s('id')]),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final day = widget.day;
    if (!day.b('overridden')) {
      final q = <String, String>{
        'employeeId': day.s('employeeId'),
        'date': day.s('dateValue'),
        if (widget.returnTo != null) 'returnTo': widget.returnTo!,
      };
      return Align(
        alignment: Alignment.centerLeft,
        child: TsLink('Override', onTap: () => context.push(Uri(path: '/attendance/override', queryParameters: q).toString())),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const TsBadge('Overridden', tone: BadgeTone.purple),
            const SizedBox(width: 10),
            TsLink(
              _pending ? 'Clearing...' : 'Clear',
              onTap: _pending ? null : _clear,
              color: _pending ? p.primary.withValues(alpha: 0.5) : null,
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: tx(12, color: p.danger)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Location

const kLocationDenied = 'Location permission was denied. Allow location access to check in.';
const kLocationFailed = "Couldn't get your location. Try again.";

/// What a location request produced: a fix, or the web's error text plus
/// which system settings screen (if any) can fix it.
class LocationFix {
  LocationFix.ok(Position this.position)
      : error = null,
        settings = null;
  LocationFix.failed(String this.error, {this.settings}) : position = null;

  final Position? position;
  final String? error;

  /// 'app' (permission permanently denied) or 'location' (services off).
  final String? settings;
}

/// A fresh high-accuracy fix (the web's `enableHighAccuracy: true,
/// timeout: 15000`), asking for permission first if needed.
Future<LocationFix> requestLocationFix() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationFix.failed(kLocationFailed, settings: 'location');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationFix.failed(kLocationDenied, settings: 'app');
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
      return LocationFix.failed(kLocationDenied);
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    return LocationFix.ok(position);
  } on PermissionDeniedException {
    return LocationFix.failed(kLocationDenied);
  } on TimeoutException {
    return LocationFix.failed(kLocationFailed);
  } catch (_) {
    return LocationFix.failed(kLocationFailed);
  }
}

Future<void> openLocationSettingsFor(String? which) async {
  if (which == 'app') {
    await Geolocator.openAppSettings();
  } else if (which == 'location') {
    await Geolocator.openLocationSettings();
  }
}

/// lib/attendance/geofence.ts's haversineDistanceMeters.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final h = math.pow(math.sin(dLat / 2), 2) + math.pow(math.sin(dLng / 2), 2) * math.cos(rad(lat1)) * math.cos(rad(lat2));
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

String distanceLabel(double meters) =>
    meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
