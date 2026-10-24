import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'backup.dart';
import 'donate.dart';
import 'main.dart';
import 'routes.dart';
import 'stepper_choice.dart';
import 'update_section.dart';
import 'ui.dart';

/// The settings popup, the same on a phone and on a desktop: theme, backup,
/// updates and support. Changes apply and are saved as they are made. It is a
/// route of its own ([Routes.settings]), so it has an address like every other
/// screen. The game options are in [Routes.gameModes].
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
                  if (updatesSupported) ...[
                    const Caption('updates'),
                    const SizedBox(height: 10),
                    const UpdateSection(),
                    const SizedBox(height: 24),
                  ],
                  const Caption('support lexodle'),
                  const SizedBox(height: 10),
                  const DonateSection(),
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
      languages: b.languages,
      history: b.history,
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
