import 'package:flutter/material.dart';

// Skema warna untuk aplikasi perawatan motor (Blue/Navy Theme - Profesional & Andal)
const Color kBg = Color(0xFFECEFF1); // background (blue gray 50 - lembut di mata)
const Color kCard = Color(0xFFFFFFFF); // primary card background
const Color kCardAlt = Color(0xFFBBDEFB); // alternate card/background (light blue)
const Color kAccent = Color(0xFF1976D2); // primary accent (professional blue - andal & terpercaya)
const Color kAccentDark = Color(0xFF0D47A1); // dark navy blue accent
const Color kAccentLight = Color(0xFF64B5F6); // light blue for highlights
const Color kMuted = Color(0xFF607D8B); // muted text (blue gray)
const Color kBorder = Color(0xFFCFD8DC); // subtle outline (blue gray)
const Color kShadow = Color(0x14000000); // soft shadow (8% black)
const Color kSuccess = Color(0xFF4CAF50); // green for success states
const Color kWarning = Color(0xFFFFA726); // amber for warnings
const Color kDanger = Color(0xFFF44336); // red for alerts/critical maintenance

ThemeData appThemeData() {
  return ThemeData(
    scaffoldBackgroundColor: kBg,
    primaryColor: kAccent,
    colorScheme: ColorScheme.fromSeed(seedColor: kAccent, surface: kBg),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: false,
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black87)),
  );
}
