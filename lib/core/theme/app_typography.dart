import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  // ── Fredoka — Bubble Text ────────────
  static TextStyle headline1() => GoogleFonts.fredoka(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
        letterSpacing: 0.5,
      );

  static TextStyle headline2() => GoogleFonts.fredoka(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      );

  static TextStyle headline3() => GoogleFonts.fredoka(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      );

  static TextStyle splashTitle() => GoogleFonts.fredoka(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppColors.orange,
        letterSpacing: 1.5,
      );

  // ── Quicksand — Interface Text ────────────────────────
  static TextStyle body() => GoogleFonts.quicksand(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.darkGray,
      );

  static TextStyle label() => GoogleFonts.quicksand(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.darkGray,
      );

  static TextStyle buttonText() => GoogleFonts.quicksand(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      );

  static TextStyle statusText() => GoogleFonts.quicksand(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.darkGray,
      );

  static TextStyle chipText() => GoogleFonts.quicksand(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      );

  // ── JetBrains Mono — Telemetry Readouts ─────────────────────────────────
  static TextStyle mono({double size = 14, Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.navy,
      );

  static TextStyle monoLarge({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.orange,
      );
}
