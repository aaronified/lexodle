import 'package:flutter/material.dart';

import 'arrow_scroll.dart';
import 'clock.dart';
import 'haptics.dart';
import 'licences.dart';
import 'routes.dart';
import 'store.dart';
import 'update_section.dart';

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

/// The app's one font (assets/fonts).
const _font = 'JetBrainsMono';

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
    fontFamily: _font,
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
        // a button's text style replaces the theme's whole, so the family is
        // named here too, or the labels are drawn in the platform's own font
        textStyle: const TextStyle(
          fontFamily: _font,
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
        textStyle: const TextStyle(fontFamily: _font, letterSpacing: 1.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        textStyle: const TextStyle(fontFamily: _font, letterSpacing: 1.2),
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
  appState.load().then((_) => checkForUpdateAtLaunch());
  // ask the server the time (for the daily); the screens redraw when it answers,
  // since the date they show may change by it
  TrustedClock.sync().then((ok) {
    if (ok) appState.refresh();
  });
  WidgetsBinding.instance.addObserver(AppResume());
  runApp(const LexodleApp());
}

/// Coming back to the app after it was left, perhaps over midnight: the day it
/// shows (the daily, the streak and its week) may have changed, so everything
/// that reads the date is drawn again, and the server's time is asked for
/// again if the last answer is old.
class AppResume with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    appState.refresh();
    if (!TrustedClock.isFresh()) {
      TrustedClock.sync().then((_) => appState.refresh());
    }
  }
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
        // up and down scroll whatever the mouse is over, on every screen
        // and a press anywhere gives a short vibration on a phone
        builder: (context, child) =>
            TapHaptics(child: ArrowScroll(child: child!)),
        onGenerateRoute: onGenerateRoute,
        onGenerateInitialRoutes: onGenerateInitialRoutes,
      ),
    );
  }
}
