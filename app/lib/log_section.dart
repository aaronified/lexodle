import 'package:flutter/material.dart';

import 'app_log.dart';
import 'main.dart';
import 'ui.dart';

/// The log section of the settings: what the app did since it started, to look
/// at or to export for sending. Exports go to the Downloads folder as text.
class LogSection extends StatefulWidget {
  const LogSection({super.key});

  @override
  State<LogSection> createState() => _LogSectionState();
}

class _LogSectionState extends State<LogSection> {
  String? _note;
  bool _error = false;
  bool _busy = false;

  Future<void> _export({required bool everything}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    final name = await appLog.export(everything: everything);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = name == null;
      _note = name == null
          ? 'could not save the log to downloads on this device'
          : 'saved to downloads: $name';
    });
  }

  void _view() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('log of this run'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              appLog.tail(200).join('\n'),
              key: const ValueKey('log-text'),
              style: const TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    final failed = appState.saveFailures;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'what the app did and what went wrong, kept on this device. it holds '
          'the app\'s own steps (start, storage, saves, backups, updates, '
          'errors), never words or guesses. send it with a problem report.',
          style: dim,
        ),
        const SizedBox(height: 8),
        Text(
          '${appLog.length} lines since this start'
          '${failed > 0 ? ' · $failed ${failed == 1 ? 'save' : 'saves'} failed' : ''}',
          key: const ValueKey('log-summary'),
          style: dim,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('log-view'),
            onPressed: _view,
            child: const Text('view this run'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('log-export-run'),
                onPressed: _busy ? null : () => _export(everything: false),
                child: const Text('export this run'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('log-export-all'),
                onPressed: _busy ? null : () => _export(everything: true),
                child: const Text('export everything'),
              ),
            ),
          ],
        ),
        if (_note != null) ...[
          const SizedBox(height: 8),
          Text(
            _note!,
            key: const ValueKey('log-note'),
            style: dim.copyWith(color: _error ? c.error : null),
          ),
        ],
      ],
    );
  }
}
