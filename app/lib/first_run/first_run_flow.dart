import 'package:flutter/material.dart';

import '../app_log.dart';
import '../main.dart' show appState;
import '../modes.dart';
import 'first_game_page.dart';
import 'first_run_state.dart';
import 'gateway_page.dart';
import 'language_theme_page.dart';
import 'modes_offer_page.dart';
import 'modes_tour_page.dart';

/// The screens of the first run, each as a builder, so a test can put fakes in
/// their place. The defaults are the real screens.
class FirstRunScreens {
  const FirstRunScreens({
    this.language = _language,
    this.game = _game,
    this.gateway = _gateway,
    this.offer = _offer,
    this.tour = _tour,
    this.lesson = _lesson,
  });

  final Widget Function(VoidCallback onStart, VoidCallback onSkip) language;
  final Widget Function(
    VoidCallback onDone,
    VoidCallback onClose,
    bool practice,
  )
  game;
  final Widget Function(VoidCallback onOkay, VoidCallback onReplay) gateway;
  final Widget Function(VoidCallback onLearn, VoidCallback onNotNow) offer;
  final Widget Function(void Function(GameMode) onLearn, VoidCallback onDone)
  tour;
  final Widget Function(GameMode mode, VoidCallback onDone) lesson;

  static Widget _language(VoidCallback onStart, VoidCallback onSkip) =>
      LanguageThemePage(onStart: onStart, onSkip: onSkip);
  static Widget _game(VoidCallback onDone, VoidCallback onClose, bool p) =>
      FirstGamePage(onDone: onDone, onClose: onClose, practice: p);
  static Widget _gateway(VoidCallback onOkay, VoidCallback onReplay) =>
      GatewayPage(onOkay: onOkay, onReplay: onReplay);
  static Widget _offer(VoidCallback onLearn, VoidCallback onNotNow) =>
      ModesOfferPage(onLearn: onLearn, onNotNow: onNotNow);
  static Widget _tour(void Function(GameMode) onLearn, VoidCallback onDone) =>
      ModesTourPage(onLearn: onLearn, onDone: onDone);

  // the lesson screen is not built yet: the tour card goes straight back
  static Widget _lesson(GameMode mode, VoidCallback onDone) =>
      _PassThrough(onDone: onDone);
}

class _PassThrough extends StatefulWidget {
  const _PassThrough({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_PassThrough> createState() => _PassThroughState();
}

class _PassThroughState extends State<_PassThrough> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// The first run: the language and theme page, the first game, the gateway,
/// the modes offer and tour, the gateway again, then the app. It has its own
/// Navigator, and ends by marking the first run done, which lets the home
/// route show the app.
class FirstRunFlow extends StatefulWidget {
  const FirstRunFlow({
    super.key,
    this.screens = const FirstRunScreens(),
    this.onFinished,
  });

  final FirstRunScreens screens;

  /// Called once the first run is done (it is already saved).
  final VoidCallback? onFinished;

  @override
  State<FirstRunFlow> createState() => _FirstRunFlowState();
}

class _FirstRunFlowState extends State<FirstRunFlow> {
  final _nav = GlobalKey<NavigatorState>();

  // the stages, as route names
  static const _language = 'language',
      _game = 'game',
      _gateway = 'gateway',
      _offer = 'offer',
      _tour = 'tour';

  FirstRunScreens get _s => widget.screens;

  void _go(String name) {
    try {
      _nav.currentState?.pushReplacementNamed(name);
    } catch (e) {
      appLog.w('first-run', 'navigation failed ${e.runtimeType}');
    }
  }

  void _pop() {
    try {
      _nav.currentState?.pop();
    } catch (e) {
      appLog.w('first-run', 'navigation failed ${e.runtimeType}');
    }
  }

  void _push(Widget page) {
    try {
      _nav.currentState?.push(MaterialPageRoute<void>(builder: (_) => page));
    } catch (e) {
      appLog.w('first-run', 'navigation failed ${e.runtimeType}');
    }
  }

  void _finish({bool chooseDailies = false}) {
    try {
      FirstRunSignals.chooseDailiesPending = chooseDailies;
      appState.setFirstRunStage(2);
      widget.onFinished?.call();
    } catch (e) {
      appLog.w('first-run', 'finish failed ${e.runtimeType}');
    }
  }

  void _gameOver() {
    try {
      if (appState.firstRunStage < 1) appState.setFirstRunStage(1);
    } catch (e) {
      appLog.w('first-run', 'stage not saved ${e.runtimeType}');
    }
    _go(_gateway);
  }

  // the game played again from a gateway: back to it when it ends
  void _replay() => _push(_s.game(_pop, _pop, true));

  void _lesson(GameMode m) {
    _push(_s.lesson(m, _pop));
  }

  Widget _screen(String name) => switch (name) {
    _language => _s.language(
      () => _go(_game),
      () => _finish(chooseDailies: true),
    ),
    _game => _s.game(_gameOver, _gameOver, false),
    _gateway => _s.gateway(
      // the first gateway goes on to the offer; the one after the tutorial ends
      _after == _tour ? _finish : () => _go(_offer),
      _replay,
    ),
    _offer => _s.offer(() => _go(_tour), () {
      _after = _tour;
      _go(_gateway);
    }),
    _ => _s.tour(_lesson, () {
      _after = _tour;
      _go(_gateway);
    }),
  };

  // set once the tutorial is left: the gateway then lands on Today
  String? _after;

  String get _start => appState.firstRunStage >= 1 ? _gateway : _language;

  @override
  Widget build(BuildContext context) => Navigator(
    key: _nav,
    initialRoute: _start,
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _screen(settings.name ?? _language),
    ),
  );
}

/// The first game played again from the you tab: it ends back there.
Route<void> practiceRoute({
  FirstRunScreens screens = const FirstRunScreens(),
}) => MaterialPageRoute<void>(
  settings: const RouteSettings(name: '/first-game'),
  builder: (context) {
    void back() {
      try {
        Navigator.of(context).pop();
      } catch (e) {
        appLog.w('first-run', 'navigation failed ${e.runtimeType}');
      }
    }

    return screens.game(back, back, true);
  },
);
