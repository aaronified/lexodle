import 'dart:async';

import 'package:lexodle/background.dart';
import 'package:lexodle/wiktionary.dart';

/// Runs before every test file. The game screens look their answers up and
/// analyse each guess while the game is played; in a test that would leave a
/// request or a timer pending when the test ends, so both are off unless a
/// test turns them on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  prefetchDefinitions = false;
  analyseWhilePlaying = false;
  await testMain();
}
