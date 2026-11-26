import 'package:flutter/material.dart';

import 'app_log.dart';
import 'collection.dart';
import 'geography.dart';
import 'main.dart';
import 'routes.dart';
import 'save_word_button.dart';
import 'saved_words.dart';
import 'tonal.dart';
import 'ui.dart';
import 'ui_kit.dart';
import 'words.dart';
import 'language_picker.dart' show allLanguages;
import 'language_sheet.dart';
import 'language_switch.dart';
import 'words_banner.dart';

/// The orders a list can be shown in; newest first is the stored order.
enum _Sort { newest, oldest, az, za }

/// "my words": the personal dictionary, newest first, with a language choice,
/// a sort menu and a search over the word, the note and the first meaning.
/// A second tab shows the words and places won (see collection.dart).
class WordsPage extends StatefulWidget {
  const WordsPage({super.key});

  @override
  State<WordsPage> createState() => _WordsPageState();
}

/// One list of the words page: what is above the rows, and the rows as a lazy
/// sliver, so only the rows on screen are built however long the list is.
class _Page {
  const _Page(this.top, [this.sliver]);
  final List<Widget> top;
  final Widget? sliver;
}

class _WordsPageState extends State<WordsPage> {
  /// The language choice; null is all of them.
  String? _lang;

  /// The order of each list, in memory only.
  _Sort _savedSort = _Sort.newest;
  _Sort _collectedSort = _Sort.newest;

  /// The sort buttons, to anchor their menus.
  final _savedSortKey = GlobalKey();
  final _collectedSortKey = GlobalKey();

  final _search = TextEditingController();
  String _query = '';

  /// The two lists are pages: 0 is the saved list, 1 the collected one.
  final _pages = PageController();
  int _page = 0;
  bool get _collected => _page == 1;

  /// The selected language of the collected tab: a language code or 'places';
  /// null is the default (the app's language, else the first one).
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
    return Column(
      children: [
        // the two lists are the header: their tabs sit in the shared title row.
        // A back arrow shows only when the page was opened on top of another.
        PageHeader(
          back: Navigator.of(context).canPop(),
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _tabs(c),
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: tonesOf(context).line,
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
    );
  }

  /// One page: its content, the rows built as they scroll into view, and the
  /// goal card of its list at the end.
  Widget _list(_Page p) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList(delegate: SliverChildListDelegate(p.top)),
        ),
        if (p.sliver != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: p.sliver!,
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverToBoxAdapter(child: _banner()),
        ),
      ],
    );
  }

  /// The saved words, and the collected words and places, counted.
  int _savedCount() => _all().length;
  int _collectedCount() => _collection()?.total ?? 0;

  /// The goal card of the list on show; none when its trophies are all earned
  /// or this target was dismissed.
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
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: WordsBanner(list: list, n: n, target: target),
      );
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

  /// The two tabs, left aligned on one line each; the selected one has a
  /// primary underline at the bottom edge of the header.
  Widget _tabs(ColorScheme c) {
    return Row(
      children: [
        _tab(
          c,
          key: const ValueKey('words-tab-saved'),
          label: 'saved ${_savedCount()}',
          selected: !_collected,
          onTap: () => _goTo(0),
        ),
        const SizedBox(width: 22),
        _tab(
          c,
          key: const ValueKey('words-tab-collected'),
          label: 'collected ${_collectedCount()}',
          selected: _collected,
          onTap: () => _goTo(1),
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
      child: Align(
        alignment: Alignment.centerLeft,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // the line below is 2 high: the same above keeps the text on
              // the centre line the cog and the other headers share
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected
                      ? c.onSurface
                      : c.onSurface.withValues(alpha: dimAlpha),
                ),
              ),
              Container(
                height: 2,
                color: selected ? c.primary : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _Page _savedBody(BuildContext context, ColorScheme c) {
    final all = _all();
    if (all.isEmpty) {
      return const _Page([
        Caption(
          'no words saved yet. tap the bookmark on the end screen of a game.',
        ),
      ]);
    }

    // a choice whose language has no saved word left is no choice
    final langs = _langs(all);
    final lang = langs.contains(_lang) ? _lang : null;

    final rows = _sortSaved(
      _filter(all, lang, _query.trim().toLowerCase()),
      _savedSort,
    );

    final top = <Widget>[
      _controlRow(
        slider: ChoiceSlider<String?>(
          id: 'words-language',
          compact: true,
          dots: false,
          title: 'language',
          footer: languagesFooter(context),
          items: [
            const ChoiceItem<String?>(
              value: null,
              label: 'all',
              name: 'all languages',
            ),
            for (final it in languageItems(
              languageStops(langs),
              _langByCode ?? const {},
            ))
              ChoiceItem<String?>(
                value: it.value,
                label: it.label,
                name: it.name,
                sub: it.sub,
                leading: languageBadge(it.value, size: 14),
                popupLeading: languageBadge(it.value, size: 22),
              ),
          ],
          selected: lang,
          onChanged: (v) => setState(() => _lang = v),
        ),
        sort: _sortButton(
          c,
          key: const ValueKey('words-sort'),
          buttonKey: _savedSortKey,
          changed: _savedSort != _Sort.newest,
          onTap: () => _openSort(
            buttonKey: _savedSortKey,
            title: 'sort saved',
            current: _savedSort,
            onPick: (s) => _savedSort = s,
          ),
        ),
      ),
      const SizedBox(height: 12),
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
      const SizedBox(height: 16),
      // the line under the search, the same on both lists
      _subtext(c, '${all.length} saved · tap a word for its entry'),
      if (rows.isEmpty) const Caption('no saved word matches.'),
    ];
    return _Page(
      top,
      rows.isEmpty
          ? null
          : SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => _row(context, c, rows[i]),
            ),
    );
  }

  _Page _collectedBody(BuildContext context, ColorScheme c) {
    final col = _collection();
    if (col == null || col.total == 0) {
      return const _Page([
        Caption(
          'no words collected yet. every word you win is collected here.',
        ),
      ]);
    }

    final langs = col.languages;
    final pills = [allLanguages, ...langs, if (col.placeCount > 0) 'places'];
    final last = _cLang;
    final sel = last != null && pills.contains(last)
        ? last
        : pills.contains(appState.lang)
        ? appState.lang
        : pills.first;

    final keys = _sortKeys(
      _cMatches(col, sel, _cQuery.trim().toLowerCase()),
      _collectedSort,
      sel == 'places',
    );

    // the count line, for a language; it reads what is already known
    String? summary;
    if (sel == allLanguages) {
      final won = _cKeys(col, sel);
      final savedHere = won.where((k) {
        final i = k.indexOf('\t');
        return _saved(k.substring(0, i), k.substring(i + 1));
      }).length;
      summary = '${won.length} words won · $savedHere saved';
    } else if (sel != 'places') {
      final won = _cKeys(col, sel);
      final savedHere = won.where((w) => _saved(sel, w)).length;
      final name = (_langByCode?[sel]?.name ?? sel).toLowerCase();
      summary = '${won.length} words won in $name · $savedHere saved here';
    }

    final top = <Widget>[
      _controlRow(
        slider: ChoiceSlider<String>(
          id: 'collected-language',
          compact: true,
          dots: false,
          title: 'language',
          footer: languagesFooter(context),
          items: [
            const ChoiceItem<String>(
              value: allLanguages,
              label: 'all',
              name: 'all languages',
            ),
            for (final it in languageItems(
              languageStops(langs),
              _langByCode ?? const {},
            ))
              ChoiceItem<String>(
                value: it.value,
                label: it.label,
                name: it.name,
                sub: it.sub,
                leading: languageBadge(it.value, size: 14),
                popupLeading: languageBadge(it.value, size: 22),
              ),
            if (col.placeCount > 0)
              const ChoiceItem<String>(
                value: 'places',
                label: 'places',
                icon: 'world',
              ),
          ],
          selected: sel,
          onChanged: (v) => setState(() => _cLang = v),
        ),
        sort: _sortButton(
          c,
          key: const ValueKey('collected-sort'),
          buttonKey: _collectedSortKey,
          changed: _collectedSort != _Sort.newest,
          onTap: () => _openSort(
            buttonKey: _collectedSortKey,
            title: 'sort collected',
            current: _collectedSort,
            onPick: (s) => _collectedSort = s,
          ),
        ),
      ),
      const SizedBox(height: 12),
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
      const SizedBox(height: 16),
      if (summary != null) _subtext(c, summary),
      if (keys.isEmpty) const Caption('no collected word matches.'),
    ];
    return _Page(
      top,
      keys.isEmpty
          ? null
          : SliverGrid.builder(
              itemCount: keys.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 52,
              ),
              itemBuilder: (context, i) {
                if (sel == 'places') return _placeTile(context, c, keys[i]);
                if (sel == allLanguages) {
                  final t = keys[i].indexOf('\t');
                  return _collectedTile(
                    context,
                    c,
                    keys[i].substring(0, t),
                    keys[i].substring(t + 1),
                    flag: true,
                  );
                }
                return _collectedTile(context, c, sel, keys[i]);
              },
            ),
    );
  }

  /// The dim line under the search: what the list holds.
  Widget _subtext(ColorScheme c, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: c.onSurface.withValues(alpha: dimAlpha),
      ),
    ),
  );

  InputDecoration _searchDecoration(ColorScheme c, String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      // the tonal fill comes from the theme; no border
      prefixIcon: Icon(
        Icons.search,
        size: 20,
        color: c.onSurface.withValues(alpha: dimAlpha),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 15),
    );
  }

  /// The language choice and the sort button, on one centre line.
  Widget _controlRow({required Widget slider, required Widget sort}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: slider),
        const SizedBox(width: 8),
        sort,
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

  /// [rows] (newest first) in the order [sort] asks; keeps them as they are
  /// when it fails.
  List<SavedWord> _sortSaved(List<SavedWord> rows, _Sort sort) {
    try {
      return switch (sort) {
        _Sort.newest => rows,
        _Sort.oldest => rows.reversed.toList(),
        _Sort.az => List.of(
          rows,
        )..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase())),
        _Sort.za => List.of(
          rows,
        )..sort((a, b) => b.word.toLowerCase().compareTo(a.word.toLowerCase())),
      };
    } catch (e) {
      appLog.w('words', 'could not sort the saved words: ${e.runtimeType}');
      return rows;
    }
  }

  /// The collected [keys] (newest first) in the order [sort] asks, by the place
  /// name when [places]; keeps them as they are when it fails.
  List<String> _sortKeys(List<String> keys, _Sort sort, bool places) {
    try {
      String name(String k) =>
          (places ? (_placeOf(k)?.name ?? k) : _wordOf(k)).toLowerCase();
      return switch (sort) {
        _Sort.newest => keys,
        _Sort.oldest => keys.reversed.toList(),
        _Sort.az => List.of(keys)..sort((a, b) => name(a).compareTo(name(b))),
        _Sort.za => List.of(keys)..sort((a, b) => name(b).compareTo(name(a))),
      };
    } catch (e) {
      appLog.w('words', 'could not sort the collected words: ${e.runtimeType}');
      return keys;
    }
  }

  /// Opens the sort menu under the button at [buttonKey]; the pick is saved
  /// with [onPick]. A failure is logged and the list keeps its order.
  Future<void> _openSort({
    required GlobalKey buttonKey,
    required String title,
    required _Sort current,
    required ValueChanged<_Sort> onPick,
  }) async {
    try {
      final c = Theme.of(context).colorScheme;
      final box = buttonKey.currentContext?.findRenderObject() as RenderBox?;
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      if (box == null || overlay == null) return;
      final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
      final picked = await showMenu<_Sort>(
        context: context,
        position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
        items: [
          PopupMenuItem<_Sort>(
            enabled: false,
            height: 28,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: c.onSurface.withValues(alpha: dimAlpha),
              ),
            ),
          ),
          _sortItem(c, _Sort.newest, 'newest first', current, 'sort-newest'),
          _sortItem(c, _Sort.oldest, 'oldest first', current, 'sort-oldest'),
          _sortItem(c, _Sort.az, 'a to z', current, 'sort-az'),
          _sortItem(c, _Sort.za, 'z to a', current, 'sort-za'),
        ],
      );
      if (picked != null && mounted) setState(() => onPick(picked));
    } catch (e) {
      appLog.w('words', 'could not open the sort menu: ${e.runtimeType}');
    }
  }

  /// One option of the sort menu; the chosen one is bold, in primary, with a
  /// check mark.
  PopupMenuItem<_Sort> _sortItem(
    ColorScheme c,
    _Sort value,
    String label,
    _Sort current,
    String key,
  ) {
    final chosen = value == current;
    return PopupMenuItem<_Sort>(
      key: ValueKey(key),
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: chosen ? FontWeight.bold : null,
                color: chosen ? c.primary : c.onSurface,
              ),
            ),
          ),
          if (chosen) Icon(Icons.check, size: 16, color: c.primary),
        ],
      ),
    );
  }

  /// The sort button: a 48 square at the element radius, green when the list
  /// is not in its default order.
  Widget _sortButton(
    ColorScheme c, {
    required Key key,
    required GlobalKey buttonKey,
    required bool changed,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: 'sort',
      button: true,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(radiusElement),
        child: Container(
          key: buttonKey,
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radiusElement),
            color: changed ? c.secondaryContainer : tonesOf(context).s1,
          ),
          child: TablerIcon(
            'arrows-sort',
            size: 22,
            color: changed ? c.onSecondaryContainer : c.onSurface,
          ),
        ),
      ),
    );
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
      if (sel == allLanguages) {
        // every language's words, a language after another, each newest first
        return [
          for (final l in col.languages)
            for (final w in col.wordsOf(l)) '$l\t$w',
        ];
      }
      return sel == 'places' ? col.places : col.wordsOf(sel);
    } catch (e) {
      appLog.w('words', 'could not list the collected words: ${e.runtimeType}');
      return const [];
    }
  }

  /// The word of a collected key: for every language the key is `lang<tab>word`.
  String _wordOf(String key) {
    final i = key.indexOf('\t');
    return i < 0 ? key : key.substring(i + 1);
  }

  /// The keys of [sel] that match [q] in the word (or in the place key and
  /// name). Falls back to every key, unfiltered, on an error.
  List<String> _cMatches(Collection col, String sel, String q) {
    final places = sel == 'places';
    try {
      return [
        for (final k in _cKeys(col, sel))
          if (q.isEmpty ||
              _wordOf(k).toLowerCase().contains(q) ||
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

  /// One saved word: an open block, no box and no rule. The word in primary
  /// with its pronunciation, the first meaning, the note, then the language and
  /// the date, with space after it.
  Widget _row(BuildContext context, ColorScheme c, SavedWord w) {
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final ipa = w.info?.ipa.firstOrNull;
    final meaning = w.firstMeaning;
    return InkWell(
      key: ValueKey('word-row-${w.lang}-${w.word}'),
      onTap: () => _open(context, w),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    w.word,
                    style: TextStyle(
                      fontSize: 20,
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
                style: const TextStyle(fontSize: 14),
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
                style: TextStyle(fontSize: 12, color: c.primary),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                languageBadge(w.lang, size: 12),
                const SizedBox(width: 8),
                Text(w.date, style: TextStyle(fontSize: 12, color: dim)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One collected word in the grid: a 52 tile at the element radius, the word
  /// in primary and the save bookmark on the right.
  Widget _collectedTile(
    BuildContext context,
    ColorScheme c,
    String lang,
    String word, {
    bool flag = false,
  }) {
    return InkWell(
      key: ValueKey('collected-row-$lang-$word'),
      onTap: () => _openCollected(context, lang, word),
      borderRadius: BorderRadius.circular(radiusElement),
      child: Ink(
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: tonesOf(context).s1,
          borderRadius: BorderRadius.circular(radiusElement),
        ),
        child: Row(
          children: [
            // in the list of every language, the flag says which one
            if (flag) ...[
              languageBadge(lang, size: 14),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                word,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.primary,
                ),
              ),
            ),
            if (_langByCode?[lang] case final language?)
              SaveWordButton(word: word, language: language, compact: true)
            else if (_saved(lang, word))
              TablerIcon('bookmark-filled', size: 16, color: c.primary),
          ],
        ),
      ),
    );
  }

  /// A place of the collection, in the grid: not tappable, its name and, when
  /// the places are loaded, what it is and where.
  Widget _placeTile(BuildContext context, ColorScheme c, String key) {
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final place = _placeOf(key);
    return Container(
      key: ValueKey('collected-place-$key'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: tonesOf(context).s1,
        borderRadius: BorderRadius.circular(radiusElement),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place?.name ?? key,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.primary,
            ),
          ),
          if (place != null)
            Text(
              '${place.kind} · ${place.country}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: dim),
            ),
        ],
      ),
    );
  }
}
