import 'package:flutter/material.dart';

/// The web app's "Atelier" design tokens (flintdoc-hr/app/globals.css),
/// one-to-one: same names, same hex values, Day and Night. Every colour in
/// the app resolves through [Ts.of], so a palette change happens here only.
class TsPalette {
  const TsPalette({
    required this.dark,
    required this.background,
    required this.foreground,
    required this.surface,
    required this.surfaceHover,
    required this.border,
    required this.muted,
    required this.primary,
    required this.primaryHover,
    required this.primaryLight,
    required this.primaryForeground,
    required this.secondary,
    required this.success,
    required this.successLight,
    required this.danger,
    required this.dangerLight,
    required this.warning,
    required this.warningLight,
    required this.info,
    required this.infoLight,
    required this.purple,
    required this.purpleLight,
    required this.accentCoral,
    required this.gradientPrimary,
    required this.gradientSoft,
    required this.washBlue,
    required this.washPeach,
    required this.washLavender,
    required this.accentBlue,
    required this.accentViolet,
    required this.accentPink,
    required this.accentYellow,
    required this.accentMint,
    required this.sidebarBg,
    required this.sidebarFg,
    required this.sidebarMuted,
    required this.sidebarHover,
    required this.brandPanel,
    required this.brandPanelFg,
    required this.brandPanelMuted,
    required this.shadowXs,
    required this.shadowCard,
    required this.shadowCardHover,
    required this.shadowButton,
    required this.shadowButtonHover,
    required this.glow,
  });

  final bool dark;
  final Color background;
  final Color foreground;
  final Color surface;
  final Color surfaceHover;
  final Color border;
  final Color muted;
  final Color primary;
  final Color primaryHover;
  final Color primaryLight;
  final Color primaryForeground;
  final Color secondary;
  final Color success;
  final Color successLight;
  final Color danger;
  final Color dangerLight;
  final Color warning;
  final Color warningLight;
  final Color info;
  final Color infoLight;
  final Color purple;
  final Color purpleLight;
  final Color accentCoral;
  final LinearGradient gradientPrimary;
  final LinearGradient gradientSoft;
  final Color washBlue;
  final Color washPeach;
  final Color washLavender;
  final Color accentBlue;
  final Color accentViolet;
  final Color accentPink;
  final Color accentYellow;
  final Color accentMint;
  final Color sidebarBg;
  final Color sidebarFg;
  final Color sidebarMuted;
  final Color sidebarHover;
  final Color brandPanel;
  final Color brandPanelFg;
  final Color brandPanelMuted;
  final List<BoxShadow> shadowXs;
  final List<BoxShadow> shadowCard;
  final List<BoxShadow> shadowCardHover;
  final List<BoxShadow> shadowButton;
  final List<BoxShadow> shadowButtonHover;

  /// `--shadow-glow`: the 4px focus ring around a focused field.
  final Color glow;

  /// Card glass: `bg-surface/80` with a `border-white/70` hairline.
  Color get glassFill => surface.withValues(alpha: 0.8);
  Color get glassBorder => dark ? border : Colors.white.withValues(alpha: 0.7);

  /// Section colours from SidebarNav.tsx's SECTION_COLOR.
  Color sectionColor(String? section) {
    switch (section) {
      case 'Hiring':
        return accentBlue;
      case 'People':
        return accentViolet;
      case 'Attendance':
        return accentMint;
      case 'Leave':
        return accentYellow;
      case 'Payroll':
        return accentPink;
      case 'Expenses':
        return accentCoral;
      case 'Tasks & KPI':
        return accentBlue;
      case 'Settings':
        return accentViolet;
      default:
        return muted;
    }
  }

  static const _ink = Color(0xFF15163A);

  // 135deg CSS gradients run top-left -> bottom-right.
  static const _diag = (Alignment.topLeft, Alignment.bottomRight);

  static List<BoxShadow> _shadow(Color c, double y, double blur) => [
    BoxShadow(color: c, offset: Offset(0, y), blurRadius: blur),
  ];

  static final light = TsPalette(
    dark: false,
    background: const Color(0xFFF3F4FA),
    foreground: _ink,
    surface: const Color(0xFFFFFFFF),
    surfaceHover: const Color(0xFFEEF0F8),
    border: const Color(0xFFE2E4EF),
    muted: const Color(0xFF5A5E78),
    primary: _ink,
    primaryHover: const Color(0xFF2A2C5E),
    primaryLight: const Color(0xFFE4E7F6),
    primaryForeground: const Color(0xFFFFFFFF),
    secondary: const Color(0xFF3A3C66),
    success: const Color(0xFF2E7D5B),
    successLight: const Color(0xFFDDF3E6),
    danger: const Color(0xFFC2413A),
    dangerLight: const Color(0xFFFBE1DE),
    warning: const Color(0xFFA8741A),
    warningLight: const Color(0xFFF8E39A),
    info: const Color(0xFF3F6FD8),
    infoLight: const Color(0xFFD5E3FB),
    purple: const Color(0xFF6E56CF),
    purpleLight: const Color(0xFFE4DDFA),
    accentCoral: const Color(0xFFF9C3A8),
    gradientPrimary: LinearGradient(
      begin: _diag.$1,
      end: _diag.$2,
      colors: const [Color(0xFF3B2FA6), Color(0xFF7C4DFF)],
    ),
    gradientSoft: LinearGradient(
      begin: _diag.$1,
      end: _diag.$2,
      colors: const [Color(0xFFBCD6FF), Color(0xFFD9CCFF), Color(0xFFFFD3BD)],
      stops: const [0, 0.55, 1],
    ),
    washBlue: const Color(0xFFB9D4FF),
    washPeach: const Color(0xFFFFD0B8),
    washLavender: const Color(0xFFD7C8FF),
    accentBlue: const Color(0xFF3F7BE8),
    accentViolet: const Color(0xFF7C4DFF),
    accentPink: const Color(0xFFEC5F9A),
    accentYellow: const Color(0xFFF2B720),
    accentMint: const Color(0xFF20B58F),
    sidebarBg: const Color(0xB8FFFFFF),
    sidebarFg: _ink,
    sidebarMuted: const Color(0xFF5A5E78),
    sidebarHover: const Color(0x0F15163A),
    brandPanel: _ink,
    brandPanelFg: const Color(0xFFFFFFFF),
    brandPanelMuted: const Color(0xFFC7C9DE),
    shadowXs: _shadow(const Color(0x0D15163A), 1, 2),
    shadowCard: _shadow(const Color(0x0F283C46), 12, 32),
    shadowCardHover: _shadow(const Color(0x1A283C46), 18, 40),
    shadowButton: _shadow(const Color(0x4015163A), 8, 18),
    shadowButtonHover: _shadow(const Color(0x4D15163A), 12, 24),
    glow: const Color(0x1F15163A),
  );

  static final night = TsPalette(
    dark: true,
    background: const Color(0xFF0C0D22),
    foreground: const Color(0xFFF3F4FA),
    surface: const Color(0xFF161838),
    surfaceHover: const Color(0xFF1E2148),
    border: const Color(0xFF2A2D5C),
    muted: const Color(0xFFA6AACB),
    primary: const Color(0xFFE4E7F6),
    primaryHover: const Color(0xFFFFFFFF),
    primaryLight: const Color(0xFF23275A),
    primaryForeground: _ink,
    secondary: const Color(0xFFA9AEEA),
    success: const Color(0xFF5FD3A0),
    successLight: const Color(0xFF123A2A),
    danger: const Color(0xFFFF8A80),
    dangerLight: const Color(0xFF3D1D22),
    warning: const Color(0xFFF8C25C),
    warningLight: const Color(0xFF3B2E12),
    info: const Color(0xFF8DB4FF),
    infoLight: const Color(0xFF15284A),
    purple: const Color(0xFFB7A7FF),
    purpleLight: const Color(0xFF2A2452),
    accentCoral: const Color(0xFFF4A98C),
    gradientPrimary: LinearGradient(
      begin: _diag.$1,
      end: _diag.$2,
      colors: const [Color(0xFFA79BFF), Color(0xFF6FD6FF)],
    ),
    gradientSoft: LinearGradient(
      begin: _diag.$1,
      end: _diag.$2,
      colors: const [Color(0xFF23275A), Color(0xFF3A2A6E), Color(0xFF4A2A3A)],
      stops: const [0, 0.55, 1],
    ),
    washBlue: const Color(0xFF1D2A66),
    washPeach: const Color(0xFF4A2A2C),
    washLavender: const Color(0xFF32246E),
    accentBlue: const Color(0xFF7FB2FF),
    accentViolet: const Color(0xFFB09CFF),
    accentPink: const Color(0xFFFF8FC0),
    accentYellow: const Color(0xFFFFD66B),
    accentMint: const Color(0xFF5FE0BD),
    sidebarBg: const Color(0xB8161838),
    sidebarFg: const Color(0xFFF3F4FA),
    sidebarMuted: const Color(0xFFA6AACB),
    sidebarHover: const Color(0x0FFFFFFF),
    brandPanel: const Color(0xFF0C0D22),
    brandPanelFg: const Color(0xFFF3F4FA),
    brandPanelMuted: const Color(0xFFA6AACB),
    shadowXs: _shadow(const Color(0x59000000), 1, 2),
    shadowCard: _shadow(const Color(0x59000000), 12, 32),
    shadowCardHover: _shadow(const Color(0x80000000), 18, 40),
    shadowButton: _shadow(const Color(0x59000000), 8, 20),
    shadowButtonHover: _shadow(const Color(0x73000000), 12, 26),
    glow: const Color(0x29E4E7F6),
  );
}

class Ts {
  static TsPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? TsPalette.night : TsPalette.light;

  static const font = 'Urbanist';

  // Tailwind radii used by the web components.
  static const rLg = 8.0; // rounded-lg
  static const rXl = 12.0; // rounded-xl
  static const r2xl = 16.0; // rounded-2xl (fields, empty states)
  static const r3xl = 24.0; // rounded-3xl (cards)
}
