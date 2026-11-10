import 'package:flutter/material.dart';

import 'app_log.dart';
import 'main.dart';
import 'routes.dart';
import 'saved_words.dart';
import 'ui.dart';

/// "my words": the personal dictionary, newest first, with a language filter,
/// a sort toggle and a search over the word, the note and the first meaning.
class WordsPage extends StatefulWidget {
  const WordsPage({super.key});

  @override
  State<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends State<WordsPage> {
  /// The language filter; null is all of them.
  String? _lang;

  /// False keeps the stored order (newest first), true sorts by word.
  bool _az = false;

  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('my words')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: appState,
            builder: (context, _) => _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final all = _all();
    if (all.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
        children: const [
          Caption(
            'no words saved yet. tap the bookmark on the end screen of a game.',
          ),
        ],
      );
    }

    // a filter whose language has no saved word left is no filter
    final langs = _langs(all);
    final lang = langs.contains(_lang) ? _lang : null;

    final rows = _filter(all, lang, _query.trim().toLowerCase());
    if (_az) _sortByWord(rows);

    return ListView(
      padding: const EdgeInsets.fromLTRB(19, 4, 19, 24),
      children: [
        Caption('${all.length} saved · tap a word for its entry'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _pill(
              c,
              key: const ValueKey('words-lang-all'),
              selected: lang == null,
              onTap: () => setState(() => _lang = null),
              child: const Text('all', style: TextStyle(fontSize: 12)),
            ),
            for (final code in langs)
              _pill(
                c,
                key: ValueKey('words-lang-$code'),
                selected: lang == code,
                onTap: () => setState(() => _lang = code),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    languageBadge(code, size: 13),
                    const SizedBox(width: 6),
                    Text(code, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            _pill(
              c,
              key: const ValueKey('words-sort'),
              selected: _az,
              onTap: () => setState(() => _az = !_az),
              child: Text(
                _az ? 'a to z' : 'newest first',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          label: 'search words and notes',
          textField: true,
          child: TextField(
            key: const ValueKey('words-search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'search words and notes',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: c.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: c.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: c.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Caption('no saved word matches.'),
          )
        else
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: c.outlineVariant),
            _row(context, c, rows[i]),
          ],
      ],
    );
  }

  /// The saved words, newest first; none when they cannot be read.
  List<SavedWord> _all() {
    try {
      return appState.savedWords.words;
    } catch (e) {
      appLog.w('words', 'could not read the saved words: ${e.runtimeType}');
      return const [];
    }
  }

  /// The distinct language codes, sorted; none when they cannot be found.
  List<String> _langs(List<SavedWord> all) {
    try {
      return ({for (final w in all) w.lang}).toList()..sort();
    } catch (e) {
      appLog.w('words', 'could not list the languages: ${e.runtimeType}');
      return const [];
    }
  }

  /// The words in [lang] (all when null) that match [q] in the word, the note
  /// or the first meaning. Falls back to every word, unfiltered, on an error.
  List<SavedWord> _filter(List<SavedWord> all, String? lang, String q) {
    try {
      return [
        for (final w in all)
          if (lang == null || w.lang == lang)
            if (q.isEmpty ||
                w.word.toLowerCase().contains(q) ||
                w.note.toLowerCase().contains(q) ||
                w.firstMeaning.toLowerCase().contains(q))
              w,
      ];
    } catch (e) {
      appLog.w('words', 'could not filter the saved words: ${e.runtimeType}');
      return List.of(all);
    }
  }

  /// Sorts [rows] by word in place; keeps the order when it fails.
  void _sortByWord(List<SavedWord> rows) {
    try {
      rows.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    } catch (e) {
      appLog.w('words', 'could not sort the saved words: ${e.runtimeType}');
    }
  }

  /// Opens the word's entry; a failed navigation is logged, not thrown.
  void _open(BuildContext context, SavedWord w) {
    try {
      // a note is typed on the entry page without telling the app, so the list
      // is drawn again when the page closes
      Navigator.pushNamed(context, Routes.word, arguments: w).then((_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      appLog.w('words', 'could not open a saved word: ${e.runtimeType}');
    }
  }

  Widget _pill(
    ColorScheme c, {
    required Key key,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? c.primary : c.outlineVariant),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: selected ? c.primary : c.onSurface),
          child: child,
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ColorScheme c, SavedWord w) {
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final ipa = w.info?.ipa.firstOrNull;
    final meaning = w.firstMeaning;
    return InkWell(
      key: ValueKey('word-row-${w.lang}-${w.word}'),
      onTap: () => _open(context, w),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    w.word,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.primary,
                    ),
                  ),
                ),
                if (ipa != null)
                  Text(ipa, style: TextStyle(fontSize: 12, color: dim)),
              ],
            ),
            if (meaning.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                meaning,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (w.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '✎ ${w.note}',
                key: ValueKey('word-note-${w.lang}-${w.word}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(fontSize: 11, color: c.primary),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                languageBadge(w.lang, size: 11),
                const SizedBox(width: 8),
                Text(w.date, style: TextStyle(fontSize: 11, color: dim)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
