import 'package:flutter/material.dart';

/// KidsZee Design System — Color Tokens
/// Aligned with kidszee.toys website palette.
/// Primary: warm orange #E0914B | Clean white backgrounds | Inter + Faculty Glyphic
abstract final class AppColors {
  // ── Background ──────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFFFFFFF);    // Clean white
  static const Color surface    = Color(0xFFF3F3F3);    // Light gray sections
  static const Color cardWhite  = Color(0xFFFFFFFF);    // Card backgrounds

  // ── Brand ───────────────────────────────────────────────────────────────────
  static const Color orange      = Color(0xFFE0914B);   // Primary brand orange (from website)
  static const Color orangeLight = Color(0xFFFDF3EB);   // Light orange tint
  static const Color terracotta  = Color(0xFFA56F4A);   // Deep warm accent (website sections)

  // ── Logo Colors ─────────────────────────────────────────────────────────────
  static const Color logoBlue   = Color(0xFF6BABE7);    // "Kids" blue
  static const Color logoOrange = Color(0xFFF5A623);    // "Zee" orange

  // ── Sky / Brand Blue (header + accent leg of orange/blue/white palette) ────
  static const Color skyBlueTop    = Color(0xFFBFE3FA);  // header gradient start
  static const Color skyBlueBottom = Color(0xFFFFFFFF);  // header gradient end (fades to white)
  static const Color brandBlue     = Color(0xFF3E9AE0);  // usable UI blue: Otto accent, blue bubbles/decor
  static const Color brandBlueDark = Color(0xFF2578B8);  // pressed/emphasis variant of brandBlue
  static const Color spiderGreen   = Color(0xFF4FA88A);  // teal-green mode accent (Spider Robot)

  // ── Typography ──────────────────────────────────────────────────────────────
  static const Color navy       = Color(0xFF121212);    // Headers (near-black, website match)
  static const Color darkGray   = Color(0xFF2B2B2B);    // Body text
  static const Color textMuted  = Color(0xFF6B7280);    // Muted / secondary text
  static const Color lightGray  = Color(0xFFE5E7EB);    // Disabled / borders

  // ── Semantic ─────────────────────────────────────────────────────────────────
  static const Color stopRed      = Color(0xFFE85D4A);  // Emergency stop
  static const Color successGreen = Color(0xFF34A853);  // Connected / ok states
  static const Color warningYellow= Color(0xFFF5A623);  // Warning states

  // ── Structure ────────────────────────────────────────────────────────────────
  static const Color border      = Color(0xFFE5E7EB);   // Subtle borders
  static const Color shadowBlack = Color(0xFF121212);    // Keep for arm painter etc
  static const Color divider     = Color(0xFFF0F0F0);   // Subtle dividers

  // ── D-Pad / Buttons ──────────────────────────────────────────────────────────
  static const Color dpadActive  = Color(0xFFE0914B);   // Pressed direction button
  static const Color dpadIdle    = Color(0xFFFFFFFF);   // Released direction button
}
