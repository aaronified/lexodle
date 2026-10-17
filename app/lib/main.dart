import 'package:flutter/material.dart';

import 'home.dart';
import 'store.dart';

/// Dustland-style minimalism on Material 3: flat paper surfaces, hairline
/// borders, near-square corners, lowercase monospace text, one accent.
const _seed = Color(0xFFB5651D);
const _radius = BorderRadius.all(Radius.circular(3));

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b).copyWith(
    surface: dark ? const Color(0xFF16140F) : const Color(0xFFF1ECE1),
    onSurface: dark ? const Color(0xFFE8E2D4) : const Color(0xFF1C1A16),
  );
  const shape = RoundedRectangleBorder(borderRadius: _radius);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'JetBrainsMono',
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(letterSpacing: 1.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        textStyle: const TextStyle(letterSpacing: 1.2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: scheme.outline),
      ),
    ),
  );
}

final appState = AppState();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  appState.load();
  runApp(const LexodleApp());
}

class LexodleApp extends StatelessWidget {
  const LexodleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'lexodle',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomePage(),
    );
  }
}
