import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'main.dart';

/// The sounds of the app, one for now: the crack of a heart in lockdown. They
/// play only when the player has not turned sound off, and a failure to play
/// (no audio device, a test) is ignored: a game never depends on a sound.
class Sounds {
  const Sounds._();

  /// Whether sounds can be played at all. Tests turn it off: there is no audio
  /// in them, and a player left running would hold a test open.
  static bool enabled = true;

  static AudioPlayer? _player;

  /// A heart breaking.
  static void crack() => _play('sounds/crack.wav');

  static void _play(String asset) {
    if (!enabled || !appState.sound) return;
    try {
      final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      unawaited(
        p
            .stop()
            .then<void>((_) => p.play(AssetSource(asset)))
            .catchError((_) {}),
      );
    } catch (_) {}
  }
}
