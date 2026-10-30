import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'update_check.dart' show appVersion;

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

void showChangelog(BuildContext context, List<String> lines) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('new in $appVersion'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final l in lines) Text('· $l')],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ok'),
        ),
      ],
    ),
  );
}
