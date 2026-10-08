import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Text in the web's Tailwind scale. Pass the px size; line-height follows
/// Tailwind's default for that size unless [height] overrides it.
/// `tracking-tight` = -0.025em, `tracking-[-0.02em]` = -0.02em.
TextStyle tx(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
  double tracking = 0,
  FontStyle? style,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: Ts.font,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height ?? _leading(size),
    letterSpacing: tracking * size,
    fontStyle: style,
    decoration: decoration,
    decorationColor: color,
  );
}

double _leading(double size) {
  if (size <= 11) return 1.4;
  if (size <= 12) return 16 / 12;
  if (size <= 14) return 20 / 14;
  if (size <= 16) return 24 / 16;
  if (size <= 18) return 28 / 18;
  if (size <= 20) return 28 / 20;
  if (size <= 24) return 32 / 24;
  if (size <= 30) return 36 / 30;
  return 1.1;
}

const kTight = -0.025;

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? TsPalette.night : TsPalette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: Ts.font,
    scaffoldBackgroundColor: p.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B2FA6),
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.primaryForeground,
      surface: p.surface,
      onSurface: p.foreground,
      error: p.danger,
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: p.border,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.primary,
      selectionColor: p.primaryLight,
      selectionHandleColor: p.accentViolet,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accentViolet),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Ts.r3xl))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ts.r3xl)),
      titleTextStyle: tx(18, weight: FontWeight.w700, color: p.foreground, tracking: kTight),
      contentTextStyle: tx(14, color: p.muted, height: 1.6),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.dark ? p.surfaceHover : p.foreground,
      contentTextStyle: tx(14, weight: FontWeight.w500, color: p.dark ? p.foreground : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ts.r2xl)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: Ts.font, bodyColor: p.foreground, displayColor: p.foreground),
  );
}
