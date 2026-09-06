import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Login page exact colors matching icon.png and design photo
  static const Color loginBg = Color(0xFFCE8733);
  static const Color loginDarkTop = Color(0xFF503518);
  static const Color loginLogoYellow = Color(0xFFE5DE9C); // Exact background color of icon.png
  static const Color loginFieldBg = Color(0xFFDD9740);
  static const Color loginButtonBg = Color(0xFFD38B30);
  static const Color loginButtonActive = Color(0xFFC47B1E);
  static const Color loginTextLight = Color(0xFFE5DE9C);
  static const Color loginTextDark = Color(0xFF352009);

  // Home page exact colors
  static const Color homeBg = Color(0xFF0F0B07);
  static const Color homeHeaderBg = Color(0xFF2A231C);
  static const Color homeSectionBg = Color(0xFF1E1711);
  static const Color homeCardBg = Color(0xFF281E16);
  static const Color homeTextCream = Color(0xFFE5DE9C);
  static const Color homeTextWhite = Color(0xFFEEEEEE);
  static const Color homeSubText = Color(0xFFAFA28A);
  static const Color homeChipBg = Color(0xFF2E241B);
  static const Color homeChipBorder = Color(0xFF4A3C2F);
  static const Color starYellow = Color(0xFFFFC107);
  static const Color avatarBlue = Color(0xFF3B68B6);

  static const Color glassBorderLight = Color(0x33FFFFFF);
  static const Color glassBorderGold = Color(0x40E5DE9C);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: AppColors.homeBg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.loginLogoYellow,
          surface: AppColors.homeBg,
        ),
      );
}
