import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui.dart';

/// Where the wiki is. The app explains things in a line; the wiki has the rest.
const wikiBase = 'https://github.com/aaronified/lexodle/wiki/';

/// The wiki pages the app points to (the file names of docs/wiki, no `.md`).
enum WikiPage {
  howToPlay('How-to-play'),
  skillLuckDaring('Skill-luck-and-daring'),
  historyAndPlaystyles('History-and-playstyles'),
  solverAndLearn('Solver-and-learn-mode'),
  dailyWord('Daily-word'),
  wordLists('Word-lists'),
  updatesAndSupport('Updates-and-support');

  const WikiPage(this.slug);
  final String slug;

  Uri get uri => Uri.parse('$wikiBase$slug');
}

/// A small "learn more" link to a wiki page, for under an explanation.
///
/// [open] is how the page is opened; tests give their own.
class WikiLink extends StatelessWidget {
  const WikiLink(this.page, {super.key, this.label = 'learn more', this.open});

  final WikiPage page;
  final String label;
  final Future<bool> Function(Uri uri)? open;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('wiki-${page.name}'),
      onTap: () => (open ?? (u) => launchUrl(u))(page.uri),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '$label ›',
          style: TextStyle(
            fontSize: 12,
            color: c.primary,
            decoration: TextDecoration.underline,
            decorationColor: c.primary.withValues(alpha: dimAlpha),
          ),
        ),
      ),
    );
  }
}
