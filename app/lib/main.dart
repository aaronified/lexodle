import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'arrow_scroll.dart';
import 'auto_backup.dart';
import 'clock.dart';
import 'equations.dart';
import 'haptics.dart';
import 'licences.dart';
import 'modes.dart' show GameMode;
import 'words.dart' show WordBank;
import 'routes.dart';
import 'shortcuts_overlay.dart';
import 'store.dart';
import 'update_check.dart';
import 'update_section.dart';
import 'app_log.dart';

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

/// The theme for [b]; [black] is the dark one on true black (for OLED screens):
/// the scaffold, surfaces and dialogs are #000000, and the outline colours are
/// kept light enough to read against it.
ThemeData buildTheme(Brightness b, {bool black = false}) {
  var scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    brightness: b,
  );
  if (black && b == Brightness.dark) {
    const k = Color(0xFF000000);
    scheme = scheme.copyWith(
      surface: k,
      surfaceDim: k,
      surfaceBright: const Color(0xFF1A1A1A),
      surfaceContainerLowest: k,
      surfaceContainerLow: k,
      surfaceContainer: k,
      surfaceContainerHigh: k,
      surfaceContainerHighest: const Color(0xFF121212),
      // the variants stay visible on black
      outlineVariant: const Color(0xFF3A3A3A),
    );
  }
  const shape = RoundedRectangleBorder(borderRadius: _radius);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    cardColor: scheme.surface,
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: shape,
    ),
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
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        textStyle: const TextStyle(fontFamily: _font, letterSpacing: 1.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        textStyle: const TextStyle(fontFamily: _font, letterSpacing: 1.2),
      ),
    ),
    // controls are flat fills, never outlines; a focused field gets a thicker
    // bottom line instead
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: const OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide.none,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHighest,
      elevation: 0,
      shape: shape,
    ),
    chipTheme: ChipThemeData(
      shape: shape,
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.secondaryContainer,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: shape,
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
      ),
    ),
  );
}

final appState = AppState();

/// The messenger of the whole app, so a toast can be shown from outside a
/// screen (the one that says a newer version is out).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerLicences();
  appLog.i('app', 'main starts');
  unawaited(appLog.start(version: appVersion));
  appState
      .load()
      .then((_) {
        // a new version keeps a copy of what it found, then looks for a newer one
        unawaited(AutoBackup.afterUpgrade(appState));
        _watchEquations();
        return checkForUpdateAtLaunch();
      })
      .then(_toastIfNewer);
  // ask the server the time (for the daily); the screens redraw when it answers,
  // since the date they show may change by it
  TrustedClock.sync().then((ok) {
    if (ok) appState.refresh();
  });
  WidgetsBinding.instance.addObserver(AppResume());
  runApp(const LexodleApp());
}

/// Scores the opening of the equations mode as soon as it is in use (chosen, or
/// already the mode at launch, or its length changed), on the worker thread.
void _watchEquations() {
  GameMode? mode;
  int? length;
  void check() {
    final now = appState.mode, n = appState.eqLength;
    final fresh = equationsNewlyInUse(mode, length, now, n);
    mode = now;
    length = n;
    if (!fresh) return;
    WordBank.languages().then((langs) {
      final lang = langs.firstWhere(
        (l) => l.code == appState.lang,
        orElse: () => langs.first,
      );
      return warmEquations(lang, n);
    });
  }

  appState.addListener(check);
  check();
}

/// Says in a toast that [version], found by the check at launch, is out, once
/// the app has a screen to show it on.
Future<void> _toastIfNewer(String? version) async {
  if (version == null) return;
  for (var i = 0; i < 50 && appMessengerKey.currentState == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  showUpdateToast(version);
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
        scaffoldMessengerKey: appMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark, black: appState.blackTheme),
        themeMode: appState.themeMode,
        initialRoute: initialRoute,
        // a mouse drags a list as a finger does
        scrollBehavior: const _EveryPointerScroll(),
        navigatorObservers: observers,
        // up and down scroll whatever the mouse is over, on every screen
        // and a press anywhere gives a short vibration on a phone
        // and Alt held shows the shortcuts and gestures
        builder: (context, child) => ShortcutsOverlay(
          child: TapHaptics(child: ArrowScroll(child: child!)),
        ),
        onGenerateRoute: onGenerateRoute,
        onGenerateInitialRoutes: onGenerateInitialRoutes,
      ),
    );
  }
}

/// Scrolling by dragging, with a mouse or a pen as well as a finger (Flutter's
/// default leaves the mouse to the wheel and the scroll bar).
class _EveryPointerScroll extends MaterialScrollBehavior {
  const _EveryPointerScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
