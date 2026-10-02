import 'package:flutter/material.dart';

// One dark theme, shared with the web dashboard: near-black, bone white, one loud accent, no rounded corners.
const ink = Color(0xFF0A0A0A);
const coal = Color(0xFF121211);
const line = Color(0xFF2B2B28);
const bone = Color(0xFFEFEFE9);
const ash = Color(0xFF9B9B93);
const volt = Color(0xFFC8FF3E);
const warn = Color(0xFFFF7A45);

const _outlined = RoundedRectangleBorder(side: BorderSide(color: line));

/// Condensed and heavy: the voice of every headline and figure. Callers set the size.
const display = TextStyle(
  fontFamily: 'Bricolage',
  fontVariations: [FontVariation('wdth', 75), FontVariation('wght', 800)],
  height: 0.95,
  letterSpacing: 0,
  color: bone,
);

/// Small technical labels and figures.
const label = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontVariations: [FontVariation('wght', 500)],
  fontSize: 11,
  letterSpacing: 1.1,
  color: ash,
);

final appTheme = ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Bricolage',
  scaffoldBackgroundColor: ink,
  colorScheme: const ColorScheme.dark(
    primary: volt,
    onPrimary: ink,
    secondary: volt,
    onSecondary: ink,
    surface: ink,
    onSurface: bone,
    onSurfaceVariant: ash,
    outline: line,
    outlineVariant: line,
    error: warn,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: ink,
    foregroundColor: bone,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    shape: Border(bottom: BorderSide(color: line)),
  ),
  cardTheme: const CardThemeData(color: coal, elevation: 0, margin: EdgeInsets.zero, shape: _outlined),
  chipTheme: ChipThemeData(
    shape: _outlined,
    side: const BorderSide(color: line),
    backgroundColor: ink,
    selectedColor: volt,
    showCheckmark: false,
    labelStyle: label.copyWith(color: bone),
  ),
  searchBarTheme: SearchBarThemeData(
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: const WidgetStatePropertyAll(coal),
    shape: const WidgetStatePropertyAll(_outlined),
    hintStyle: WidgetStatePropertyAll(label.copyWith(fontSize: 13, letterSpacing: 0)),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: bone,
      shape: const RoundedRectangleBorder(),
      side: const BorderSide(color: line),
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: label,
    ),
  ),
  listTileTheme: const ListTileThemeData(shape: Border(bottom: BorderSide(color: line))),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: volt, linearTrackColor: line),
);
