import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui.dart';
import 'words.dart';
import 'wiktionary.dart';

/// Meaning, pronunciation, synonyms and antonyms of the answer, from
/// en.wiktionary.org. Shown after the game ends; every failure degrades to a
/// one-line note, since the game itself never depends on the network.
class WordInfoView extends StatefulWidget {
  const WordInfoView({super.key, required this.word, required this.language});
  final String word;
  final Language language;

  @override
  State<WordInfoView> createState() => _WordInfoViewState();
}

class _WordInfoViewState extends State<WordInfoView> {
  late final Future<WordInfo?> _future = Wiktionary()
      .lookup(widget.word, widget.language.code, widget.language.wikt);
  AudioPlayer? _player;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _play(String url) async {
    try {
      _player ??= AudioPlayer();
      await _player!.stop();
      await _player!.play(UrlSource(url));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return FutureBuilder<WordInfo?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Caption('looking up in wiktionary…');
        }
        final info = snap.data;
        if (snap.hasError) {
          return const Caption('could not reach wiktionary');
        }
        if (info == null || info.isEmpty) {
          return const Caption('no wiktionary entry for this word');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.ipa.isNotEmpty || info.audio != null)
              Row(children: [
                Flexible(child: Text(info.ipa.join('  '))),
                if (info.audio != null)
                  IconButton(
                    tooltip: 'listen',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.volume_up_outlined, size: 20),
                    onPressed: () => _play(info.audio!),
                  ),
              ]),
            for (final b in info.blocks) ...[
              const SizedBox(height: 8),
              Caption(b.pos),
              const SizedBox(height: 4),
              for (var i = 0; i < b.definitions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('${i + 1}. ${b.definitions[i]}',
                      style: const TextStyle(fontSize: 13)),
                ),
            ],
            if (info.synonyms.isNotEmpty) _nyms('synonyms', info.synonyms),
            if (info.antonyms.isNotEmpty) _nyms('antonyms', info.antonyms),
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
              onPressed: () => launchUrl(Uri.parse(info.url)),
              child: Text('wiktionary ↗', style: TextStyle(color: c.primary)),
            ),
          ],
        );
      },
    );
  }

  Widget _nyms(String label, List<String> words) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Caption(label),
          const SizedBox(height: 2),
          Text(words.join(', '), style: const TextStyle(fontSize: 13)),
        ]),
      );
}
