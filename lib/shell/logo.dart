import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/tokens.dart';

/// The TeamSavy wordmark: the colour SVG in Day mode, white in Night mode
/// (the web swaps the two with `dark:hidden` / `dark:block`).
class TeamSavyLogo extends StatelessWidget {
  const TeamSavyLogo({super.key, this.height = 20, this.forceWhite = false});
  final double height;
  final bool forceWhite;

  @override
  Widget build(BuildContext context) {
    final white = forceWhite || Ts.of(context).dark;
    return SvgPicture.asset(
      white ? 'assets/images/teamsavy-logo-white.svg' : 'assets/images/teamsavy-logo-color.svg',
      height: height,
      semanticsLabel: 'TeamSavy',
    );
  }
}

/// The tenant's own uploaded logo (GET /api/files/logo), fetched once per
/// session with the bearer token and cached in memory.
class TenantLogo extends StatefulWidget {
  const TenantLogo({super.key, this.size = 28, this.padding = 4, this.radius = 8});
  final double size;
  final double padding;
  final double radius;

  static Uint8List? _cache;
  static String? _cacheFor;

  static void clear() {
    _cache = null;
    _cacheFor = null;
  }

  @override
  State<TenantLogo> createState() => _TenantLogoState();
}

class _TenantLogoState extends State<TenantLogo> {
  @override
  void initState() {
    super.initState();
    final key = session.me?.raw['organizationId']?.toString();
    if (TenantLogo._cache == null || TenantLogo._cacheFor != key) {
      api.bytes('/api/files/logo').then((b) {
        TenantLogo._cache = b;
        TenantLogo._cacheFor = key;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final bytes = TenantLogo._cache;
    return Container(
      width: widget.size,
      height: widget.size,
      padding: EdgeInsets.all(widget.padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: p.shadowXs,
      ),
      child:
          bytes == null
              ? null
              : (_isSvg(bytes)
                  ? SvgPicture.memory(bytes, fit: BoxFit.contain)
                  : Image.memory(bytes, fit: BoxFit.contain)),
    );
  }

  bool _isSvg(Uint8List b) {
    final head = String.fromCharCodes(b.take(200)).toLowerCase();
    return head.contains('<svg') || head.contains('<?xml');
  }
}

/// Logo + optional company name, as in Topbar/Sidebar.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) {
    final me = session.me;
    final p = Ts.of(context);
    if (me != null && me.hasLogo) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TenantLogo(size: large ? 36 : 28, padding: large ? 6 : 4, radius: large ? 12 : 8),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              me.companyName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Ts.font,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
                color: p.foreground,
              ),
            ),
          ),
        ],
      );
    }
    return TeamSavyLogo(height: large ? 24 : 20);
  }
}
