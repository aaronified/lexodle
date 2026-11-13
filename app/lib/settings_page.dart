import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'auto_backup.dart';
import 'backup.dart';
import 'changelog.dart';
import 'donate.dart';
import 'haptics.dart';
import 'sounds.dart';
import 'log_section.dart';
import 'precomputed_local.dart';
import 'precomputed_section.dart';
import 'main.dart';
import 'routes.dart';
import 'update_section.dart';
import 'ui.dart';
import 'wiki_links.dart';

/// The settings page: theme, touch, reminders, backup, updates, log, support,
/// what's new, and the way to about and licences. Each section has its caption,
/// its controls and at most one short line, and opens with its step of the
/// ladder. Changes apply and are saved as they are made. It is a route of its
/// own ([Routes.settings]), so it has an address like every other screen. The
/// game options are in [Routes.gameModes].
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  /// The changelog again, whatever was seen.
  Future<void> _showChanges(BuildContext context) async {
    try {
      final lines = await loadChangelog();
      if (lines.isEmpty || !context.mounted) return;
      showChangelog(context, lines);
    } catch (e) {
      appLog.w('changelog', 'whats new failed ${e.runtimeType}');
    }
  }

  void _push(BuildContext context, String route) {
    try {
      Navigator.pushNamed(context, route);
    } catch (e) {
      appLog.w('settings', 'open failed ${e.runtimeType}');
    }
  }

  Widget _row(
    BuildContext context,
    String id,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('settings-row-$id'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: c.onSurface.withValues(alpha: dimAlpha),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: c.onSurface.withValues(alpha: dimAlpha),
            ),
          ],
        ),
      ),
    );
  }

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
                final dark = appState.themeMode == ThemeMode.dark;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
                  children: [
                    if (appState.stepOpen('theme')) ...[
                      const Caption('theme'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final (m, label) in const [
                            (ThemeMode.light, 'light'),
                            (ThemeMode.dark, 'dark'),
                            (ThemeMode.system, 'system'),
                          ])
                            Expanded(
                              child: InkWell(
                                key: ValueKey('theme-$label'),
                                onTap: () => appState.setup(
                                  themeMode: m,
                                  black:
                                      m == ThemeMode.dark &&
                                      appState.blackTheme,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: appState.themeMode == m
                                        ? c.secondaryContainer
                                        : c.surfaceContainerHighest,
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontWeight: appState.themeMode == m
                                          ? FontWeight.bold
                                          : null,
                                      color: appState.themeMode == m
                                          ? c.onSecondaryContainer
                                          : c.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SwitchListTile(
                        key: const ValueKey('black-switch'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('true black'),
                        subtitle: Text(
                          'for OLED screens: pure #000000 when dark',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.onSurface.withValues(alpha: dimAlpha),
                          ),
                        ),
                        value: appState.blackTheme,
                        onChanged: dark
                            ? (on) => appState.setup(
                                themeMode: ThemeMode.dark,
                                black: on,
                              )
                            : null,
                      ),
                      const SizedBox(height: 24),
                    ],
                    const Caption('touch'),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      key: const ValueKey('haptics-switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('vibrate on press'),
                      subtitle: Text(
                        'a tap of feedback on phones.',
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
                    SwitchListTile(
                      key: const ValueKey('sound-switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('sound'),
                      subtitle: Text(
                        'the crack of a heart in lockdown.',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.onSurface.withValues(alpha: dimAlpha),
                        ),
                      ),
                      value: appState.sound,
                      onChanged: (on) {
                        appState.setSound(on);
                        if (on) Sounds.crack();
                      },
                    ),
                    const SizedBox(height: 24),
                    if (appState.stepOpen('reminders')) ...[
                      _row(
                        context,
                        'reminders',
                        'reminders',
                        'a ping when your dailies open',
                        () => _push(context, Routes.reminders),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (appState.stepOpen('backup')) ...[
                      const Caption('backup'),
                      const SizedBox(height: 10),
                      const _BackupSection(),
                      const SizedBox(height: 24),
                    ],
                    if (updatesSupported) ...[
                      const Caption('updates'),
                      const SizedBox(height: 10),
                      const UpdateSection(),
                      const SizedBox(height: 24),
                    ],
                    if (PrecomputedLocal.supported) ...[
                      const Caption('faster openings'),
                      const SizedBox(height: 10),
                      const PrecomputedSection(),
                      const SizedBox(height: 24),
                    ],
                    const Caption('log'),
                    const SizedBox(height: 10),
                    const LogSection(),
                    const SizedBox(height: 24),
                    if (appState.stepOpen('support')) ...[
                      const Caption('support lexodle'),
                      const SizedBox(height: 10),
                      const DonateSection(),
                      const SizedBox(height: 24),
                    ],
                    if (appState.stepOpen("what's new")) ...[
                      _row(
                        context,
                        'whatsnew',
                        "what's new",
                        'what changed in this version',
                        () => _showChanges(context),
                      ),
                      const SizedBox(height: 24),
                    ],
                    const Caption('about'),
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
          'could not save to downloads; kept in the app instead',
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
      learn: b.learn,
      words: b.words,
      collected: b.collected,
      lex: b.lex,
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
        Text('your progress lives on this device. keep a copy.', style: dim),
        const WikiLink(WikiPage.updatesAndSupport),
        const SizedBox(height: 6),
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
            'latest automatic backup: ${_auto!.name}',
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
            'from ${pending.exported.toIso8601String().substring(0, 10)}: '
            '${_plural(pending.stats.played, 'game')} '
            '(${pending.stats.wins} won), '
            '${_plural(pending.earned, 'achievement')}. '
            'replaces what is saved here: '
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
