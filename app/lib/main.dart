import 'package:flutter/material.dart';

import 'licences.dart';
import 'routes.dart';
import 'store.dart';

/// Dustland-style minimalism on Material 3: flat surfaces, hairline borders,
/// near-square corners, lowercase monospace text. Every colour comes from the
/// generated Material You scheme and nothing is hard-coded.
///
/// The seed and the `expressive` variant are chosen for the hues they give the
/// roles: secondary is green (right place) and primary purple (the hardest
/// difficulty); the wrong-place yellow is its own hue, see ui.dart. On Android
/// the same roles would come from the wallpaper instead.
final _seed = HSLColor.fromAHSL(1, 48, .7, .5).toColor();
const _radius = BorderRadius.all(Radius.circular(3));

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    brightness: b,
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
  registerLicences();
  appState.load();
  runApp(const LexodleApp());
}

class LexodleApp extends StatelessWidget {
  /// [initialRoute] is for tests; the app starts at the address it was opened
  /// at (the browser's, on the web).
  const LexodleApp({super.key, this.initialRoute, this.observers = const []});
  final String? initialRoute;
  final List<NavigatorObserver> observers;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => MaterialApp(
        title: 'lexodle',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: appState.themeMode,
        initialRoute: initialRoute,
        navigatorObservers: observers,
        onGenerateRoute: onGenerateRoute,
        onGenerateInitialRoutes: onGenerateInitialRoutes,
      ),
    );
  }
}
