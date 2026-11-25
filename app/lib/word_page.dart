import 'package:flutter/material.dart';

import 'app_log.dart';
import 'main.dart';
import 'saved_words.dart';
import 'ui.dart';
import 'ui_kit.dart';
import 'word_info.dart';
import 'wiktionary.dart';
import 'words.dart';

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
  bool _retrying = false;
  String _retryNote = '';

  /// Looks the word up again, in the word's own language, and keeps the entry
  /// on the saved word (its note is left as it is). Every failure is logged
  /// and told in one line; the page keeps working.
  Future<void> _retry() async {
    if (_retrying) return;
    final entry = widget.entry;
    setState(() {
      _retrying = true;
      _retryNote = '';
    });
    var note = '';
    try {
      final langs = await WordBank.languages();
      final lang = langs.firstWhere((l) => l.code == entry.lang);
      final info = await Wiktionary.shared
          .lookup(entry.word, lang.code, lang.wikt)
          .timeout(const Duration(seconds: 12));
      if (info == null || info.isEmpty) {
        note = 'no entry found for this word';
      } else {
        appState.setWordInfo(entry.lang, entry.word, info);
      }
    } catch (e) {
      appLog.w('word', 'the lookup failed again: ${e.runtimeType}');
      note = 'could not look it up. try again later';
    }
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _retryNote = note;
    });
  }

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
  Widget _entryBody(WordInfo info, Widget saved) {
    try {
      return WordInfoBody(info: info, saved: saved);
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
    final saved = HeaderInfo(
      'saved ${entry.date}',
      leading: languageBadge(entry.lang, size: 14),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: const SizedBox.shrink(),
              back: true,
              settings: false,
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      Text(
                        entry.word,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (hasInfo)
                        _entryBody(info, saved)
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: saved,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Caption(
                          'no entry was kept. add your own notes below.',
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const ValueKey('word-retry'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 36),
                            ),
                            onPressed: _retrying ? null : _retry,
                            child: Text(
                              _retrying
                                  ? 'looking it up…'
                                  : 'try the lookup again',
                              style: TextStyle(color: c.primary),
                            ),
                          ),
                        ),
                        if (_retryNote.isNotEmpty) Caption(_retryNote),
                      ],
                      const SectionLabel('your note'),
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
                        icon: TablerIcon(
                          'trash-x',
                          size: 18,
                          color: c.onSurface,
                        ),
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
                                onPressed: () =>
                                    setState(() => _confirming = false),
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
            ),
          ],
        ),
      ),
    );
  }
}
