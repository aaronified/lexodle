import 'package:flutter/material.dart';

import 'app_log.dart';
import 'main.dart';
import 'saved_words.dart';
import 'ui.dart';
import 'word_info.dart';
import 'wiktionary.dart';

/// One saved word with its entry and note: the copy of the Wiktionary entry
/// from the day it was saved, a note kept as the player types, and removal.
class WordPage extends StatefulWidget {
  const WordPage({super.key, required this.entry});
  final SavedWord entry;

  @override
  State<WordPage> createState() => _WordPageState();
}

class _WordPageState extends State<WordPage> {
  late final TextEditingController _note = TextEditingController(
    text: widget.entry.note,
  );
  bool _confirming = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _remove() {
    try {
      appState.unsaveWord(widget.entry.lang, widget.entry.word);
      Navigator.pop(context);
    } catch (e) {
      appLog.w('word', 'the word could not be removed: ${e.runtimeType}');
    }
  }

  void _onNoteChanged(String value) {
    try {
      appState.setWordNote(widget.entry.lang, widget.entry.word, value);
    } catch (e) {
      appLog.w('word', 'the note could not be saved: ${e.runtimeType}');
    }
  }

  /// The entry copy, or a caption when building it throws (the error is logged).
  Widget _entryBody(WordInfo info) {
    try {
      return WordInfoBody(info: info);
    } catch (e) {
      appLog.w('word', 'the entry could not be shown: ${e.runtimeType}');
      return const Caption('could not show this entry');
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final c = Theme.of(context).colorScheme;
    final info = entry.info;
    final hasInfo = info != null && !info.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            languageBadge(entry.lang, size: 16),
            const SizedBox(width: 8),
            const Text('my words'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(19, 4, 19, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      entry.word,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: c.primary,
                      ),
                    ),
                  ),
                  Caption('saved ${entry.date}'),
                ],
              ),
              if (hasInfo) ...[
                const SizedBox(height: 8),
                _entryBody(info),
              ] else
                Caption('no entry was kept for this word'),
              const SizedBox(height: 18),
              Caption('your note'),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('word-note'),
                controller: _note,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'a line to remember it by',
                ),
                onChanged: _onNoteChanged,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Caption('kept as you type'),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  'this is a copy of the wiktionary entry from the day it was saved, so it opens without a connection. only listening needs one.',
                  style: TextStyle(
                    fontSize: 11,
                    color: c.onSurface.withValues(alpha: dimAlpha),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                key: const ValueKey('word-remove'),
                onPressed: () => setState(() => _confirming = true),
                icon: TablerIcon('trash-x', size: 18, color: c.onSurface),
                label: const Text('remove from my words'),
              ),
              if (_confirming) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('word-remove-yes'),
                        onPressed: _remove,
                        child: const Text('remove it'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('word-remove-no'),
                        onPressed: () => setState(() => _confirming = false),
                        child: const Text('keep it'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
