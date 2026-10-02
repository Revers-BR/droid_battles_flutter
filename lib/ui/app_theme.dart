import 'package:flutter/material.dart';

/// Tema do app -- visual de "jogo mobile" (fundo escuro, acentos em
/// neon), não uma cópia do Qt cinza do original. Sem equivalente no
/// C++: isto é 100% novo, pensado pra toque/tela pequena.
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0B0E14);
  static const Color surface = Color(0xFF151A24);
  static const Color surfaceAlt = Color(0xFF1E2531);
  static const Color accent = Color(0xFF35E0A6); // verde-neon (armadura/ok)
  static const Color accentWarn = Color(0xFFE0B035); // amarelo (calor)
  static const Color accentDanger = Color(0xFFE0354F); // vermelho (dano/erro)
  static const Color accentInfo = Color(0xFF35A6E0); // azul (combustível)
  static const Color textDim = Color(0xFF8A93A6);

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentInfo,
        surface: surface,
        error: accentDanger,
      ),
      fontFamily: 'monospace',
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceAlt,
        selectedColor: accent,
        labelStyle: const TextStyle(color: Colors.white),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
