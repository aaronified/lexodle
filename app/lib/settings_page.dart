import 'dart:convert';

import 'package:flutter/material.dart';

import 'auto_backup.dart';
import 'backup.dart';
import 'donate.dart';
import 'haptics.dart';
import 'log_section.dart';
import 'main.dart';
import 'routes.dart';
import 'stepper_choice.dart';
import 'update_section.dart';
import 'ui.dart';

/// The settings page: theme, backup, updates, support, and about. Changes apply
/// and are saved as they are made. It is a route of its own ([Routes.settings]),
/// so it has an address like every other screen. The game options are in
/// [Routes.gameModes].
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: appState,
              builder: (context, _) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
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
                    const Caption('touch'),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      key: const ValueKey('haptics-switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('vibrate on press'),
                      subtitle: Text(
                        'a light tap for a letter, a click for backspace, a '
                        'medium one for enter, a knock for a word that is not '
                        'allowed. phones only',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.onSurface.withValues(alpha: dimAlpha),
                        ),
                      ),
                      value: appState.haptics,
                      onChanged: (on) {
                        appState.setHaptics(on);
                        // so the player feels what was just turned on
                        if (on) Haptics.fire(Haptic.submit);
                      },
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
                    const Caption('log'),
                    const SizedBox(height: 10),
                    const LogSection(),
                    const SizedBox(height: 24),
                    const Caption('support lexodle'),
                    const SizedBox(height: 10),
                    const DonateSection(),
                    const SizedBox(height: 24),
                    const Caption('about'),
                    const SizedBox(height: 10),
                    Text(
                      aboutText,
                      key: const ValueKey('about-text'),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: c.onSurface.withValues(alpha: dimAlpha),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        key: const ValueKey('licences-button'),
                        onPressed: () =>
                            Navigator.pushNamed(context, Routes.about),
                        child: const Text('about and licences'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
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

  /// The newest automatic backup kept in the app's own storage, if any.
  ({String name, String text})? _auto;

  @override
  void initState() {
    super.initState();
    _loadAuto();
  }

  Future<void> _loadAuto() async {
    final latest = await AutoBackup.latest();
    if (mounted) setState(() => _auto = latest);
  }

  /// Saves a backup to the Downloads folder now, without asking where.
  Future<void> _toDownloads() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pending = null;
      _note = null;
    });
    try {
      final r = await AutoBackup.run(
        appState,
        downloads: true,
        label: 'manual',
      );
      if (!mounted) return;
      if (r.downloads) {
        _say('saved to downloads: ${r.name}');
      } else if (r.internal) {
        _say(
          'could not save to downloads on this device; a copy is in the '
          'app\'s memory',
          error: true,
        );
      } else {
        _say('could not save a backup', error: true);
      }
      await _loadAuto();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reads the latest automatic backup, for the player to confirm.
  void _readAuto() {
    final a = _auto;
    if (a == null) return;
    try {
      setState(() {
        _pending = parseBackup(a.text);
        _note = null;
      });
    } on FormatException {
      _say('that backup could not be read', error: true);
    }
  }

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
      final saved = await saveBackupFile(appState);
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
          'restore it. every update also backs up by itself.',
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
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('backup-downloads'),
            onPressed: _busy ? null : _toDownloads,
            child: const Text('save a backup to downloads'),
          ),
        ),
        if (_auto != null) ...[
          const SizedBox(height: 10),
          Text(
            'the latest automatic backup, kept in the app\'s memory: '
            '${_auto!.name}',
            key: const ValueKey('backup-auto-name'),
            style: dim,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey('backup-restore-auto'),
              onPressed: _busy ? null : _readAuto,
              child: const Text('restore the latest automatic backup'),
            ),
          ),
        ],
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
