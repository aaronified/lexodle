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
  late final Future<WordInfo?> _future = Wiktionary.shared.lookup(
    widget.word,
    widget.language.code,
    widget.language.wikt,
  );
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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      info.ipa.join('   '),
                      style: TextStyle(color: c.primary, fontSize: 15),
                    ),
                  ),
                  if (info.audio != null)
                    IconButton(
                      tooltip: 'listen',
                      visualDensity: VisualDensity.compact,
                      color: c.primary,
                      icon: const Icon(Icons.volume_up_outlined, size: 20),
                      onPressed: () => _play(info.audio!),
                    ),
                ],
              ),
            for (final b in info.blocks) ...[
              const SizedBox(height: 12),
              _heading(c, b),
              const SizedBox(height: 6),
              for (var i = 0; i < b.senses.length; i++)
                _sense(c, i + 1, b.senses[i]),
            ],
            if (info.etymology.isNotEmpty) ...[
              const SizedBox(height: 12),
              _label('origin', yellowOf(c)),
              const SizedBox(height: 2),
              Text(
                info.etymology,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: c.onSurface.withValues(alpha: .75),
                ),
              ),
            ],
            if (info.synonyms.isNotEmpty)
              _nyms(
                'synonyms',
                info.synonyms,
                c.secondaryContainer,
                c.onSecondaryContainer,
              ),
            if (info.antonyms.isNotEmpty)
              _nyms(
                'antonyms',
                info.antonyms,
                c.errorContainer,
                c.onErrorContainer,
              ),
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => launchUrl(Uri.parse(info.url)),
              child: Text('wiktionary ↗', style: TextStyle(color: c.primary)),
            ),
          ],
        );
      },
    );
  }

  /// The part of speech in the accent colour, then gender and forms.
  Widget _heading(ColorScheme c, PosBlock b) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: b.pos,
          style: TextStyle(
            color: c.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        if (b.gender.isNotEmpty)
          TextSpan(
            text: '  ${b.gender}',
            style: TextStyle(color: c.secondary, fontWeight: FontWeight.bold),
          ),
        if (b.forms.isNotEmpty)
          TextSpan(
            text: '  ${b.forms}',
            style: TextStyle(color: c.onSurface.withValues(alpha: dimAlpha)),
          ),
      ],
    ),
    style: const TextStyle(fontSize: 12),
  );

  /// One numbered sense: labels in the warm colour, the gloss, then examples
  /// under a green rule.
  Widget _sense(ColorScheme c, int n, Sense s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$n  ',
                style: TextStyle(color: c.primary, fontWeight: FontWeight.bold),
              ),
              if (s.labels.isNotEmpty)
                TextSpan(
                  text: '${s.labels.join(', ')}  ',
                  style: TextStyle(
                    color: yellowOf(c),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              TextSpan(text: s.text),
            ],
          ),
          style: const TextStyle(fontSize: 13),
        ),
        for (final e in s.examples)
          Container(
            margin: const EdgeInsets.only(left: 14, top: 4),
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: c.secondary, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.text,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: c.onSurface.withValues(alpha: .9),
                  ),
                ),
                if (e.translation.isNotEmpty)
                  Text(
                    e.translation,
                    style: TextStyle(
                      fontSize: 11,
                      color: c.onSurface.withValues(alpha: .55),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _label(String text, Color color) => Text(
    text,
    style: TextStyle(fontSize: 12, letterSpacing: 2, color: color),
  );

  /// Related words as small tinted chips.
  Widget _nyms(String label, List<String> words, Color bg, Color fg) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, fg.withValues(alpha: .9)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final w in words)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(w, style: TextStyle(fontSize: 12, color: fg)),
              ),
          ],
        ),
      ],
    ),
  );
}
