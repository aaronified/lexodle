import 'package:flutter/material.dart';

import 'achievements_page.dart' show achievementCount;
import 'changelog.dart';
import 'clock.dart';
import 'daily.dart';
import 'daily_streak.dart';
import 'logo.dart';
import 'style_chip.dart';
import 'main.dart';
import 'mode_wheel.dart';
import 'modes.dart' show Draw;
import 'routes.dart';
import 'store.dart' show Achievement, achievements;
import 'ui.dart';
import 'update_check.dart' show appVersion;
import 'words.dart';

/// The height of the play button, the buttons beside it and the menu buttons.
const _buttonHeight = 52.0;

/// The narrowest window that counts as a desktop. Narrower is a phone, where the
/// play row sticks to the bottom of the screen; on a desktop it floats, as the
/// last row of the page.
const _desktopWidth = 600.0;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Language>? _langs;

  bool _howToShown = false;

  @override
  void initState() {
    super.initState();
    WordBank.languages().then((l) => setState(() => _langs = l));
    appState.addListener(_maybeShowChanges);
    appState.addListener(_maybeShowHowTo);
    _maybeShowChanges();
    _maybeShowHowTo();
  }

  @override
  void dispose() {
    appState.removeListener(_maybeShowChanges);
    appState.removeListener(_maybeShowHowTo);
    super.dispose();
  }

  bool _changesChecked = false;

  /// First start of a new version, for someone who has played before: lists
  /// what changed in it, once.
  Future<void> _maybeShowChanges() async {
    if (_changesChecked || !appState.loaded || !appState.canRemember) return;
    _changesChecked = true;
    final returning = appState.seenHowTo;
    if (appState.changelogSeen == appVersion) return;
    appState.noteChangelogSeen(appVersion);
    if (!returning || !showWhatsNew) return;
    final lines = await loadChangelog();
    if (lines.isEmpty || !mounted) return;
    showChangelog(context, lines);
  }

  /// First visit: open how to play once, and remember that it was shown.
  void _maybeShowHowTo() {
    if (_howToShown || !appState.loaded || appState.seenHowTo) return;
    if (!appState.canRemember) return;
    _howToShown = true;
    appState.markHowToSeen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushNamed(
          context,
          Routes.howTo,
          arguments: onboardingArgument,
        );
      }
    });
  }

  /// The small second line under "daily": where today's daily word stands for
  /// [lang], or null before it is started.
  String? _dailyStatus(String lang) {
    final mode = appState.mode;
    final e = appState.dailyFor(lang, dailyDate(), mode);
    if (e == null) return null;
    if (!e.over) return '${e.guesses.length}/${dailyTriesOf(mode)}';
    return e.won! ? 'solved in ${e.guesses.length}' : 'missed';
  }

  /// "daily", with the status in a smaller font under it so a long status
  /// never wraps the button label onto three rows.
  Widget _dailyChild(String lang) {
    final status = _dailyStatus(lang);
    if (status == null) return const Text('daily');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('daily'),
        Text(status, style: const TextStyle(fontSize: 11, height: 1.1)),
      ],
    );
  }

  Language _current(List<Language> langs) => langs.firstWhere(
    (l) => l.code == appState.lang,
    orElse: () => langs.first,
  );

  /// The language card: its flag and name, which opens a popup of every
  /// language in two columns. Back (the phone's, or tapping outside) closes it
  /// and keeps the language.
  Widget _languageCard(
    BuildContext context,
    List<Language> langs,
    Language lang,
    int length,
  ) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      key: const ValueKey('language-button'),
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final code = await showDialog<String>(
          context: context,
          builder: (context) => LanguagePopup(langs: langs, current: lang.code),
        );
        if (code == null || code == lang.code) return;
        final next = langs.firstWhere((l) => l.code == code);
        appState.setup(
          lang: code,
          length: next.lengths.contains(length) ? length : next.lengths.first,
        );
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: c.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            FlagBadge(lang.flag),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.name,
                key: const ValueKey('language-name'),
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// How the answer is drawn, just above the play row: what it is in a few
  /// words. A tap goes on to the next of the three; the longer sentence is a
  /// toast.
  Widget _frequencyRow(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final draw = appState.draw;
    void next() {
      final d = Draw.values[(draw.index + 1) % Draw.values.length];
      appState.setup(draw: d);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            content: Text(switch (d) {
              Draw.sigmoid =>
                'the commonest words are about equally likely, then fewer '
                    'and fewer. the daily always draws this way.',
              Draw.equal =>
                'every word of the length is equally likely. the daily '
                    'draws by the curve.',
              Draw.frequency =>
                'common words come up more often. the daily draws by the '
                    'curve.',
            }),
          ),
        );
    }

    return InkWell(
      key: const ValueKey('frequency-row'),
      borderRadius: BorderRadius.circular(4),
      onTap: next,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'word draw · ${draw.label}',
                key: const ValueKey('frequency-label'),
                style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
              ),
            ),
            // where it is among the three, as on the steppers
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                key: const ValueKey('frequency-dots'),
                children: [
                  for (final d in Draw.values)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d == draw ? c.primary : c.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// The play row, the last row of the page: the mode button (its name, with
  /// chevrons, and a swipe over the whole area, turn the loop of modes; a tap
  /// opens the game modes), then play and the daily of that mode. Play shows no
  /// mode text: the button above it says which.
  Widget _playRow(BuildContext context, Language lang) {
    // a label that does not fit shrinks, so a long status never wraps
    Widget fit(Widget w) => FittedBox(fit: BoxFit.scaleDown, child: w);
    return ModeSwitch(
      mode: appState.mode,
      lang: appState.lang,
      height: _buttonHeight,
      onChanged: (m) => appState.setup(mode: m),
      onOpen: () => Navigator.pushNamed(context, Routes.gameModes),
      below: Row(
        children: [
          Expanded(
            child: FilledButton(
              key: const ValueKey('play-button'),
              style: FilledButton.styleFrom(
                fixedSize: const Size.fromHeight(_buttonHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
              onPressed: () => Navigator.pushNamed(context, Routes.play),
              child: const Text('play'),
            ),
          ),
          if (appState.mode.hasDaily) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('daily-button'),
                style: OutlinedButton.styleFrom(
                  fixedSize: const Size.fromHeight(_buttonHeight),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () async {
                  // the daily goes by the server's time: ask again if it has not
                  // been for a while
                  if (!TrustedClock.isFresh()) {
                    await TrustedClock.sync(
                      timeout: const Duration(milliseconds: 1500),
                    );
                  }
                  if (!context.mounted) return;
                  Navigator.pushNamed(context, Routes.daily);
                },
                child: fit(_dailyChild(lang.code)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The most recently earned achievements, newest first, at most [n]: across
  /// the global ones and the current language's.
  List<Achievement> _recentAchievements([int n = 3]) {
    final ach = appState.ach;
    final earned = [
      for (final a in achievements)
        if ((ach[a.id]?.times ?? 0) > 0 && ach[a.id]!.latest != null) a,
    ]..sort((x, y) => ach[y.id]!.latest!.compareTo(ach[x.id]!.latest!));
    return earned.take(n).toList();
  }

  /// A full-width menu button, as tall as play. [trailing] sits on its right.
  Widget _menuButton(
    String label,
    String route, {
    Key? key,
    Widget? trailing,
  }) => SizedBox(
    width: double.infinity,
    height: _buttonHeight,
    child: OutlinedButton(
      key: key,
      onPressed: () => Navigator.pushNamed(context, route),
      child: trailing == null
          ? Text(label)
          : Row(
              children: [
                Expanded(child: Text(label)),
                trailing,
              ],
            ),
    ),
  );

  /// The glyphs of the latest achievements, newest first, or null for none.
  Widget? _recentGlyphs(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final recent = _recentAchievements();
    if (recent.isEmpty) return null;
    return Row(
      key: const ValueKey('recent-achievements'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in recent)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: TablerIcon(
              a.icon,
              key: ValueKey('recent-ach-${a.id}'),
              size: 22,
              color: c.primary,
            ),
          ),
      ],
    );
  }

  /// The playstyle's glyph button and a history button beside it, a row like
  /// the achievements one.
  Widget _styleRow(BuildContext context) => Row(
    children: [
      StyleChip(
        size: _buttonHeight,
        onTap: () => Navigator.pushNamed(context, Routes.playstyle),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SizedBox(
          height: _buttonHeight,
          child: OutlinedButton(
            key: const ValueKey('history-button'),
            onPressed: () => Navigator.pushNamed(context, Routes.history),
            child: const Text('history'),
          ),
        ),
      ),
    ],
  );

  /// The frequency row above the play row.
  Widget _bottomBar(BuildContext context, Language lang) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _frequencyRow(context),
      const SizedBox(height: 4),
      _playRow(context, lang),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final langs = _langs;
    final c = Theme.of(context).colorScheme;
    // a phone sticks the play row to the bottom of the screen; a desktop lets it
    // float as the last row of the page
    return Scaffold(
      body: SafeArea(
        // (the width the page is given, so a window and a test both decide it)
        child: LayoutBuilder(
          builder: (context, outer) {
            final phone = outer.maxWidth < _desktopWidth;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: langs == null
                    ? const SizedBox()
                    : ListenableBuilder(
                        listenable: appState,
                        builder: (context, _) {
                          final lang = _current(langs);
                          final length = lang.lengths.contains(appState.length)
                              ? appState.length
                              : lang.lengths.first;
                          final unlocked = appState.unlockedCount;
                          return Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    19,
                                    40,
                                    19,
                                    24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          const LexodleLogo(width: 56),
                                          const SizedBox(width: 16),
                                          // the name shrinks before it can crowd the
                                          // settings button
                                          Expanded(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'lexodle',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displaySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          // settings, with about inside it
                                          IconButton(
                                            tooltip: 'settings',
                                            constraints: const BoxConstraints(
                                              minWidth: 48,
                                              minHeight: 48,
                                            ),
                                            // the app's own icon set, like the
                                            // buttons below
                                            icon: Semantics(
                                              label: 'settings',
                                              child: TablerIcon(
                                                'settings',
                                                size: 28,
                                                color: c.onSurface,
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.pushNamed(
                                                  context,
                                                  Routes.settings,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      const Caption(
                                        'a word game, in many tongues',
                                      ),
                                      const SizedBox(height: 28),
                                      // the card says what it is (a flag and a
                                      // name), so it has no header
                                      _languageCard(
                                        context,
                                        langs,
                                        lang,
                                        length,
                                      ),
                                      const SizedBox(height: 20),
                                      const DailyStreak(),
                                      const SizedBox(height: 28),
                                      const Divider(),
                                      const SizedBox(height: 12),
                                      _menuButton(
                                        'achievements  $unlocked/${achievementCount()}',
                                        Routes.achievements,
                                        key: const ValueKey(
                                          'achievements-button',
                                        ),
                                        trailing: _recentGlyphs(context),
                                      ),
                                      const SizedBox(height: 8),
                                      _styleRow(context),
                                      const SizedBox(height: 8),
                                      _menuButton(
                                        'how to play',
                                        Routes.howTo,
                                        key: const ValueKey('how-to-button'),
                                      ),
                                      // on a desktop the row floats: the last row
                                      if (!phone) ...[
                                        const SizedBox(height: 20),
                                        _bottomBar(context, lang),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // on a phone it sticks to the bottom
                              if (phone)
                                Padding(
                                  key: const ValueKey('pinned-play'),
                                  padding: const EdgeInsets.fromLTRB(
                                    19,
                                    8,
                                    19,
                                    16,
                                  ),
                                  child: _bottomBar(context, lang),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Every language in two columns. Tapping one closes it with that language's
/// code; back, or a tap outside, closes it with nothing.
class LanguagePopup extends StatelessWidget {
  const LanguagePopup({super.key, required this.langs, required this.current});
  final List<Language> langs;
  final String current;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    // the app's own background, and a rectangular box like game modes
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: c.outline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            key: const ValueKey('language-grid'),
            shrinkWrap: true,
            crossAxisCount: 2,
            childAspectRatio: 3.4,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (final l in langs)
                InkWell(
                  key: ValueKey('language-option-${l.code}'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Navigator.pop(context, l.code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: l.code == current
                          ? c.primary.withValues(alpha: .15)
                          : null,
                      border: Border.all(
                        color: l.code == current ? c.primary : c.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        FlagBadge(l.flag, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
