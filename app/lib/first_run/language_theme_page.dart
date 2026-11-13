import 'package:flutter/material.dart';

import '../app_log.dart';
import '../main.dart' show appState;
import '../ui.dart';
import '../words.dart';

/// The first screen of the first run: the language, the theme (light, dark,
/// system and true black, as the you page has them), then start playing. A
/// veteran skips the first game with the text button.
class LanguageThemePage extends StatefulWidget {
  const LanguageThemePage({
    super.key,
    required this.onStart,
    required this.onSkip,
    this.languages,
  });

  final VoidCallback onStart;
  final VoidCallback onSkip;

  /// The languages to list; the word lists' own by default.
  final Future<List<Language>>? languages;

  @override
  State<LanguageThemePage> createState() => _LanguageThemePageState();
}

class _LanguageThemePageState extends State<LanguageThemePage> {
  static const _few = 3;
  List<Language> _all = const [];
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ls = await (widget.languages ?? WordBank.languages());
      if (mounted) setState(() => _all = ls);
    } catch (e) {
      appLog.w('first-run', 'languages not loaded ${e.runtimeType}');
    }
  }

  void _setLang(String code) {
    try {
      appState.setup(lang: code);
    } catch (e) {
      appLog.w('first-run', 'language not set ${e.runtimeType}');
    }
  }

  void _setTheme(ThemeMode m) {
    try {
      appState.setup(
        themeMode: m,
        black: m == ThemeMode.dark && appState.blackTheme,
      );
    } catch (e) {
      appLog.w('first-run', 'theme not set ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: appState,
              builder: (context, _) {
                final dark = appState.themeMode == ThemeMode.dark;
                var shown = _all;
                if (!_more && _all.length > _few) {
                  shown = _all.take(_few).toList();
                  final cur = _all.where((l) => l.code == appState.lang);
                  if (cur.isNotEmpty && !shown.contains(cur.first)) {
                    shown = [...shown.take(_few - 1), cur.first];
                  }
                }
                final hidden = _all.length - shown.length;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(19, 24, 19, 24),
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'lexodle',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'guess the word. colours tell you how close.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.onSurface.withValues(alpha: dimAlpha),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Caption('language'),
                    const SizedBox(height: 8),
                    for (final l in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: appState.lang == l.code
                              ? c.secondaryContainer
                              : c.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            key: ValueKey('lang-${l.code}'),
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _setLang(l.code),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 56),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Row(
                                children: [
                                  FlagBadge(l.flag, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l.name.toLowerCase(),
                                      style: TextStyle(
                                        color: appState.lang == l.code
                                            ? c.onSecondaryContainer
                                            : c.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (hidden > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const ValueKey('more-languages'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: () => setState(() => _more = true),
                          child: Text('$hidden more languages'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Material(
                      color: c.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: hairline(c),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                      onTap: () => _setTheme(m),
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 44,
                                        ),
                                        alignment: Alignment.center,
                                        color: appState.themeMode == m
                                            ? c.secondaryContainer
                                            : c.surfaceContainerHigh,
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
                              title: const Text('true black'),
                              subtitle: Text(
                                'for OLED screens: pure #000000 when dark',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.onSurface.withValues(
                                    alpha: dimAlpha,
                                  ),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const ValueKey('start-playing'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: widget.onStart,
                      child: const Text('start playing'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('i-know'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: widget.onSkip,
                      child: const Text('i know how lexodle works'),
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
