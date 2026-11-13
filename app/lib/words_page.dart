import 'package:flutter/material.dart';

import 'app_log.dart';
import 'collection.dart';
import 'geography.dart';
import 'main.dart';
import 'routes.dart';
import 'save_word_button.dart';
import 'saved_words.dart';
import 'ui.dart';
import 'words.dart';
import 'words_banner.dart';

/// "my words": the personal dictionary, newest first, with a language filter,
/// a sort toggle and a search over the word, the note and the first meaning.
/// A second tab shows the words and places won (see collection.dart).
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

  /// The two lists are pages: 0 is the saved list, 1 the collected one.
  final _pages = PageController();
  int _page = 0;
  bool get _collected => _page == 1;

  /// The selected pill of the collected tab: a language code or 'places'; null
  /// is the default (the app's language, else the first pill).
  String? _cLang;

  final _cSearch = TextEditingController();
  String _cQuery = '';

  /// The languages by code, for the save buttons; null until they are known.
  Map<String, Language>? _langByCode;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  /// Fills [_langByCode]: at once when the languages are loaded already, else
  /// when they are. A failure is logged; the rows then show no save button.
  void _loadLanguages() {
    try {
      final hit = WordBank.loadedLanguages;
      if (hit != null) {
        _langByCode = _indexLanguages(hit);
        return;
      }
      WordBank.languages()
          .then((ls) {
            if (mounted) setState(() => _langByCode = _indexLanguages(ls));
          })
          .catchError((Object e) {
            appLog.w('words', 'could not load the languages: ${e.runtimeType}');
          });
    } catch (e) {
      appLog.w('words', 'could not load the languages: ${e.runtimeType}');
    }
  }

  Map<String, Language> _indexLanguages(List<Language> ls) {
    return {for (final l in ls) l.code: l};
  }

  @override
  void dispose() {
    _search.dispose();
    _cSearch.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // no title: the two lists are the header. A bar stays only to go back
      // when the page was opened on top of another.
      appBar: Navigator.of(context).canPop() ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: appState,
              builder: (context, _) => _body(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 8, 19, 14),
              child: _tabs(c),
            ),
            Expanded(
              child: PageView(
                key: const ValueKey('words-pages'),
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _list(_savedBody(context, c)),
                  _list(_collectedBody(context, c)),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 19,
          right: 19,
          bottom: 12,
          child: _banner(),
        ),
      ],
    );
  }

  /// One page: its content, with room under it for the floating banner.
  Widget _list(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(19, 0, 19, 140),
      children: children,
    );
  }

  /// The saved words, and the collected words and places, counted.
  int _savedCount() => _all().length;
  int _collectedCount() => _collection()?.total ?? 0;

  /// The banner of the list on show; none when its trophies are all earned or
  /// this target was dismissed.
  Widget _banner() {
    try {
      final saved = !_collected;
      final list = saved ? 'saved' : 'collected';
      final n = saved ? _savedCount() : _collectedCount();
      final target = nextTrophy(saved ? 'saved_words' : 'collected', n);
      if (target == null ||
          appState.dismissedWordBanners.contains('$list:$target')) {
        return const SizedBox.shrink();
      }
      return WordsBanner(list: list, n: n, target: target);
    } catch (e) {
      appLog.w('words', 'could not show the banner: ${e.runtimeType}');
      return const SizedBox.shrink();
    }
  }

  void _goTo(int i) {
    try {
      _pages.animateToPage(
        i,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (e) {
      appLog.w('words', 'could not change the list: ${e.runtimeType}');
      setState(() => _page = i);
    }
  }

  Widget _tabs(ColorScheme c) {
    return Row(
      children: [
        Expanded(
          child: _tab(
            c,
            key: const ValueKey('words-tab-saved'),
            label: 'saved ${_savedCount()}',
            selected: !_collected,
            onTap: () => _goTo(0),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _tab(
            c,
            key: const ValueKey('words-tab-collected'),
            label: 'collected ${_collectedCount()}',
            selected: _collected,
            onTap: () => _goTo(1),
          ),
        ),
      ],
    );
  }

  Widget _tab(
    ColorScheme c, {
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected ? c.secondaryContainer : c.surfaceContainerHighest,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.bold : null,
            color: selected ? c.onSecondaryContainer : c.onSurface,
          ),
        ),
      ),
    );
  }

  List<Widget> _savedBody(BuildContext context, ColorScheme c) {
    final all = _all();
    if (all.isEmpty) {
      return const [
        Caption(
          'no words saved yet. tap the bookmark on the end screen of a game.',
        ),
      ];
    }

    // a filter whose language has no saved word left is no filter
    final langs = _langs(all);
    final lang = langs.contains(_lang) ? _lang : null;

    final rows = _filter(all, lang, _query.trim().toLowerCase());
    if (_az) _sortByWord(rows);

    return [
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
          decoration: _searchDecoration(c, 'search words and notes'),
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
          if (i > 0) Divider(height: 1, thickness: 1, color: c.outlineVariant),
          _row(context, c, rows[i]),
        ],
    ];
  }

  List<Widget> _collectedBody(BuildContext context, ColorScheme c) {
    final col = _collection();
    if (col == null || col.total == 0) {
      return const [
        Caption(
          'no words collected yet. every word you win is collected here.',
        ),
      ];
    }

    final langs = col.languages;
    final pills = [...langs, if (col.placeCount > 0) 'places'];
    final last = _cLang;
    final sel = last != null && pills.contains(last)
        ? last
        : pills.contains(appState.lang)
        ? appState.lang
        : pills.first;

    final keys = _cMatches(col, sel, _cQuery.trim().toLowerCase());

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final code in langs)
            _pill(
              c,
              key: ValueKey('collected-lang-$code'),
              selected: sel == code,
              onTap: () => setState(() => _cLang = code),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  languageBadge(code, size: 13),
                  const SizedBox(width: 6),
                  Text(code, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          if (col.placeCount > 0)
            _pill(
              c,
              key: const ValueKey('collected-lang-places'),
              selected: sel == 'places',
              onTap: () => setState(() => _cLang = 'places'),
              child: const Text('places', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      const SizedBox(height: 14),
      Semantics(
        label: 'search collected words',
        textField: true,
        child: TextField(
          key: const ValueKey('collected-search'),
          controller: _cSearch,
          onChanged: (v) => setState(() => _cQuery = v),
          style: const TextStyle(fontSize: 14),
          decoration: _searchDecoration(c, 'search collected words'),
        ),
      ),
      const SizedBox(height: 8),
      if (keys.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Caption('no collected word matches.'),
        )
      else
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: c.outlineVariant),
          if (sel == 'places')
            _placeRow(c, keys[i])
          else
            _collectedRow(context, c, sel, keys[i]),
        ],
    ];
  }

  InputDecoration _searchDecoration(ColorScheme c, String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      // flat fill from the theme; no outline
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

  /// Opens a collected word's entry; a failed navigation is logged, not thrown.
  void _openCollected(BuildContext context, String lang, String word) {
    try {
      Navigator.pushNamed(
        context,
        Routes.collected,
        arguments: CollectedRef(lang, word),
      ).then((_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      appLog.w('words', 'could not open a collected word: ${e.runtimeType}');
    }
  }

  /// The collection, or null when it cannot be read.
  Collection? _collection() {
    try {
      return appState.collection;
    } catch (e) {
      appLog.w('words', 'could not read the collected words: ${e.runtimeType}');
      return null;
    }
  }

  /// Whether the word is in the personal dictionary; false when that cannot
  /// be read.
  bool _saved(String lang, String word) {
    try {
      return appState.isWordSaved(lang, word);
    } catch (e) {
      appLog.w('words', 'could not read a saved word: ${e.runtimeType}');
      return false;
    }
  }

  /// The place a key names, once the places are loaded; null when not.
  Place? _placeOf(String key) {
    try {
      return Geography.placeOf(key);
    } catch (e) {
      appLog.w('words', 'could not read a place: ${e.runtimeType}');
      return null;
    }
  }

  /// The words of [sel] (or the place keys for 'places'), newest first; none
  /// when they cannot be listed.
  List<String> _cKeys(Collection col, String sel) {
    try {
      return sel == 'places' ? col.places : col.wordsOf(sel);
    } catch (e) {
      appLog.w('words', 'could not list the collected words: ${e.runtimeType}');
      return const [];
    }
  }

  /// The keys of [sel] that match [q] in the word (or in the place key and
  /// name). Falls back to every key, unfiltered, on an error.
  List<String> _cMatches(Collection col, String sel, String q) {
    final places = sel == 'places';
    try {
      return [
        for (final k in _cKeys(col, sel))
          if (q.isEmpty ||
              k.toLowerCase().contains(q) ||
              (places && (_placeOf(k)?.name ?? '').toLowerCase().contains(q)))
            k,
      ];
    } catch (e) {
      appLog.w(
        'words',
        'could not filter the collected words: ${e.runtimeType}',
      );
      return _cKeys(col, sel);
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
          color: selected ? c.secondaryContainer : c.surfaceContainerHighest,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: selected ? c.onSecondaryContainer : c.onSurface,
            fontWeight: selected ? FontWeight.bold : null,
          ),
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

  Widget _collectedRow(
    BuildContext context,
    ColorScheme c,
    String lang,
    String word,
  ) {
    return InkWell(
      key: ValueKey('collected-row-$lang-$word'),
      onTap: () => _openCollected(context, lang, word),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                word,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.primary,
                ),
              ),
            ),
            if (_langByCode?[lang] case final language?)
              SaveWordButton(word: word, language: language)
            else if (_saved(lang, word))
              TablerIcon('bookmark-filled', size: 16, color: c.primary),
          ],
        ),
      ),
    );
  }

  /// A place of the collection: not tappable, its name and, when the places
  /// are loaded, what it is and where.
  Widget _placeRow(ColorScheme c, String key) {
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final place = _placeOf(key);
    return Padding(
      key: ValueKey('collected-place-$key'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place?.name ?? key,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.primary,
            ),
          ),
          if (place != null)
            Text(
              '${place.kind} · ${place.country}',
              style: TextStyle(fontSize: 11, color: dim),
            ),
        ],
      ),
    );
  }
}
