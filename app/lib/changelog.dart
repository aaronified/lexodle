import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'app_log.dart';
import 'page_sheet.dart';
import 'update_check.dart' show appVersion;

/// Whether the first start of a new version shows what changed. The tests turn
/// it off (see test/flutter_test_config.dart): the release workflow fills the
/// list before it runs them, and a dialog would cover every home screen.
bool showWhatsNew = true;

/// The summaries of what changed in this version, one per line. The release
/// workflow writes them into assets/changelog.txt from CHANGELOG.md; the file
/// is empty in the repository.
List<String> parseChangelog(String raw) => [
  for (final l in raw.split('\n'))
    if (l.trim().isNotEmpty) l.trim(),
];

Future<List<String>> loadChangelog() async {
  try {
    return parseChangelog(await rootBundle.loadString('assets/changelog.txt'));
  } catch (_) {
    return const [];
  }
}

/// What changed in this version, as a sheet from the bottom.
void showChangelog(BuildContext context, List<String> lines) {
  try {
    Navigator.of(context)
        .push(PageSheetRoute<void>(builder: (_) => ChangelogSheet(lines)));
  } catch (e) {
    appLog.w('changelog', 'could not open ${e.runtimeType}');
  }
}

class ChangelogSheet extends StatelessWidget {
  const ChangelogSheet(this.lines, {super.key});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return PageSheet(
      title: 'new in $appVersion',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('· $l'),
            ),
        ],
      ),
    );
  }
}
