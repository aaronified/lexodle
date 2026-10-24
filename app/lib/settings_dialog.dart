import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'backup.dart';
import 'main.dart';
import 'modes.dart';
import 'routes.dart';
import 'stepper_choice.dart';
import 'store.dart';
import 'ui.dart';

/// The settings popup, the same on a phone and on a desktop: game mode, how
/// often its words share letters, the helper level, play and the solver. Changes
/// apply and are saved as they are made. It is a route of its own
/// ([Routes.settings]), so it has an address like every other screen.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: c.outline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final mode = appState.mode;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Caption('mode'),
                  const SizedBox(height: 10),
                  StepperChoice<GameMode>(
                    semanticLabel: 'mode',
                    items: [
                      for (final m in GameMode.values)
                        (
                          m,
                          m.label,
                          m.extraTries == 0
                              ? m.sub
                              : '${m.sub} · +${m.extraTries} tries',
                        ),
                    ],
                    selected: mode,
                    onChanged: (m) => appState.setup(mode: m),
                  ),
                  const SizedBox(height: 24),
                  // always there, so the settings keep one shape; one word has
                  // nothing to share, so in classic it is greyed and fixed
                  Row(
                    children: [
                      const Expanded(child: Caption('shared letters')),
                      Text(
                        '${appState.share}%',
                        key: const ValueKey('share-value'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: mode.multi
                              ? c.primary
                              : c.onSurface.withValues(alpha: dimAlpha),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    key: const ValueKey('share-slider'),
                    value: appState.share.toDouble(),
                    min: 0,
                    max: maxShare.toDouble(),
                    divisions: maxShare,
                    label: '${appState.share}%',
                    onChanged: mode.multi
                        ? (v) => appState.setup(share: v.round())
                        : null,
                  ),
                  Text(
                    !mode.multi
                        ? 'one word has nothing to share. this applies to '
                              'quartet and relay race.'
                        : appState.share == 0
                        ? 'the words never share a letter, as far as the '
                              'language allows.'
                        : 'the chance that the words share a letter. '
                              'lower makes them more different.',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.onSurface.withValues(alpha: dimAlpha),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Caption('helper'),
                  const SizedBox(height: 10),
                  // the helper only shows in classic, so for the other modes
                  // it is greyed: dimmed, and out of reach of touch and keys
                  Opacity(
                    key: const ValueKey('helper-fade'),
                    opacity: mode.multi ? .38 : 1,
                    child: AbsorbPointer(
                      absorbing: mode.multi,
                      child: ExcludeFocus(
                        excluding: mode.multi,
                        child: StepperChoice<Helper>(
                          semanticLabel: 'helper',
                          items: [
                            for (final h in Helper.values) (h, h.label, h.sub),
                          ],
                          selected: appState.helper,
                          onChanged: (h) => appState.setup(helper: h),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    mode.multi
                        ? 'the helper shows in classic mode only. whatever you '
                              'choose, everything is revealed when the game ends.'
                        : 'whatever you choose, everything is revealed when '
                              'the game ends.',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.onSurface.withValues(alpha: dimAlpha),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Caption('theme'),
                  const SizedBox(height: 10),
                  StepperChoice<ThemeMode>(
                    semanticLabel: 'theme',
                    items: const [
                      (ThemeMode.system, 'system', 'follow the device'),
                      (ThemeMode.light, 'light', 'a light page'),
                      (ThemeMode.dark, 'dark', 'a dark page'),
                    ],
                    selected: appState.themeMode,
                    onChanged: (t) => appState.setup(themeMode: t),
                  ),
                  const SizedBox(height: 24),
                  const Caption('backup'),
                  const SizedBox(height: 10),
                  const _BackupSection(),
                  const SizedBox(height: 24),
                  const Caption('play or solve'),
                  const SizedBox(height: 10),
                  // both replace the popup, so back from either is home
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('settings-play'),
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            Routes.play,
                          ),
                          child: const Text('play'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            Routes.solver,
                          ),
                          child: const Text('open the solver'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _plural(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';

/// Download everything that is saved as a file, or restore it from one. On the
/// web this is the persistent storage: the browser's own can be cleared at any
/// time, and a file can be moved to another device.
class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  String? _note;
  bool _error = false;
  bool _busy = false;

  /// A checked backup waiting for the player to say it may replace what is
  /// saved.
  Backup? _pending;

  void _say(String text, {bool error = false}) => setState(() {
    _note = text;
    _error = error;
  });

  Future<void> _download() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pending = null;
      _note = null;
    });
    try {
      final bytes = Uint8List.fromList(utf8.encode(backupToText(appState)));
      final saved = await BackupIO.current.save(
        backupFileName(DateTime.now()),
        bytes,
      );
      if (mounted) _say(saved ? 'backup saved' : 'nothing was saved');
    } catch (_) {
      if (mounted) _say('could not save the backup', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pending = null;
      _note = null;
    });
    try {
      final file = await BackupIO.current.pick();
      if (file == null) return; // cancelled
      final text = utf8.decode(file.bytes); // not text: a FormatException
      final backup = parseBackup(text);
      if (mounted) setState(() => _pending = backup);
    } on FormatException catch (e) {
      if (mounted) {
        _say(
          e.message.startsWith('that')
              ? e.message
              : 'that file is not a lexodle backup',
          error: true,
        );
      }
    } catch (_) {
      if (mounted) _say('could not read that file', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _restore(Backup b) {
    appState.restore(
      settings: b.settings,
      stats: b.stats,
      ach: b.achievements,
      dailyLog: b.dailyLog,
      dailyBest: b.dailyBest,
    );
    setState(() {
      _pending = null;
      _error = false;
      _note =
          'restored: ${_plural(b.stats.played, 'game')}, '
          '${_plural(b.earned, 'achievement')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 11,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    final pending = _pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'your progress is kept on this device only. download a backup to '
          'keep it safe or move it to another device, and upload one to '
          'restore it.',
          style: dim.copyWith(height: 1.4),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('backup-download'),
                onPressed: _busy ? null : _download,
                child: const Text('download'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('backup-upload'),
                onPressed: _busy ? null : _upload,
                child: const Text('upload'),
              ),
            ),
          ],
        ),
        if (pending != null) ...[
          const SizedBox(height: 12),
          Text(
            'backup from ${pending.exported.toIso8601String().substring(0, 10)}: '
            '${_plural(pending.stats.played, 'game')} '
            '(${pending.stats.wins} won), '
            '${_plural(pending.earned, 'achievement')}. '
            'this replaces what is saved here: '
            '${_plural(appState.stats.played, 'game')}, '
            '${_plural(appState.unlockedCount, 'achievement')}.',
            key: const ValueKey('backup-summary'),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('backup-confirm'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => _restore(pending),
                  child: const Text('replace my progress'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('backup-cancel'),
                onPressed: () => setState(() => _pending = null),
                child: const Text('cancel'),
              ),
            ],
          ),
        ],
        if (_note != null) ...[
          const SizedBox(height: 10),
          Text(
            _note!,
            key: const ValueKey('backup-note'),
            style: TextStyle(
              fontSize: 12,
              color: _error ? c.error : c.secondary,
            ),
          ),
        ],
      ],
    );
  }
}
