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
import 'reminders.dart';
import 'shortcuts_overlay.dart';
import 'store.dart';
import 'update_check.dart';
import 'update_section.dart';
import 'app_log.dart';
import 'tonal.dart';
import 'ui.dart' show radiusContainer, radiusElement, radiusSheet;

/// The look of the app: flat tonal surfaces on a generated tonal ramp (see
/// tonal.dart), lowercase monospace text. Four rules shape every widget: space
/// before containment (groups are told apart by distance and tone, not lines),
/// one edge language (a surface is filled or outlined, not both), a control
/// rhythm (heights 36, 40, 48, 56) and radius by role (see ui.dart).
///
/// The scheme, and the tones above the page, come from [schemeOf] and
/// [AppTones]; nothing here is written as a colour.
const _radius = BorderRadius.all(Radius.circular(radiusElement));

/// The app's one font (assets/fonts).
const _font = 'JetBrainsMono';

/// The theme for [b]; [black] is the dark one on true black (for OLED screens).
ThemeData buildTheme(Brightness b, {bool black = false}) {
  final ground = b == Brightness.light
      ? Ground.cream
      : (black ? Ground.black : Ground.night);
  final scheme = schemeOf(ground);
  final tones = AppTones.of(ground);
  const shape = RoundedRectangleBorder(borderRadius: _radius);
  const container = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radiusContainer)),
  );
  const labelStyle = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
    fontSize: 15,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [tones],
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    cardColor: scheme.surface,
    // a dialog is a filled container with no edge
    dialogTheme: DialogThemeData(
      backgroundColor: tones.s1,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      elevation: 12,
      shape: container,
    ),
    // a sheet is the page colour, raised by a shadow, rounded at the top
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: null,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      elevation: 16,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tones.s1,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      elevation: 8,
      shape: container,
    ),
    fontFamily: _font,
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        fontWeight: FontWeight.bold,
        fontSize: 22,
        color: scheme.onSurface,
      ),
    ),
    // the action of a screen: the pink fill
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        minimumSize: const Size(0, 48),
        textStyle: labelStyle,
      ),
    ),
    // every other button is a tonal fill with no edge
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        minimumSize: const Size(0, 48),
        side: BorderSide.none,
        backgroundColor: tones.s2,
        foregroundColor: scheme.onSurface,
        textStyle: labelStyle,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        textStyle: const TextStyle(fontFamily: _font, letterSpacing: 1),
      ),
    ),
    // a field is a tonal fill; focused, it gets the pink ring
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tones.s1,
      border: const OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: tones.s1,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: container,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: tones.s1,
      selectedColor: scheme.secondaryContainer,
    ),
    // off is a track a tone above the card with a dim knob, on is the green
    // track with its own knob
    switchTheme: SwitchThemeData(
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackOutlineWidth: const WidgetStatePropertyAll(0),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? scheme.secondary : tones.s3,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? scheme.onSecondary
            : scheme.onSurfaceVariant,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: shape,
        side: BorderSide.none,
        backgroundColor: tones.s1,
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: tones.s3,
      linearMinHeight: 6,
    ),
  );
}

final appState = AppState();

/// The messenger of the whole app, so a toast can be shown from outside a
/// screen (the one that says a newer version is out).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// The navigator of the whole app, so a tapped notification can open a daily.
final appNavigatorKey = GlobalKey<NavigatorState>();

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
        // reminders: a tapped notification opens that mode's daily; the plan is rebuilt now and on every change
        Reminders.onOpen = (m) {
          appState.setup(mode: m);
          appNavigatorKey.currentState?.pushNamed(Routes.daily);
        };
        Reminders.start();
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
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark, black: appState.blackTheme),
        themeMode: appState.themeMode,
        initialRoute: initialRoute,
        // a mouse drags a list as a finger does
        scrollBehavior: const AppScrollBehavior(),
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
/// default leaves the mouse to the wheel and the scroll bar), and the Material
/// stretch at the ends of every list on every platform, as on Android 12.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => StretchingOverscrollIndicator(
    axisDirection: details.direction,
    clipBehavior: details.decorationClipBehavior ?? Clip.hardEdge,
    child: child,
  );

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
