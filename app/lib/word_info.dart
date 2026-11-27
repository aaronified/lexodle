import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'root_meaning.dart';
import 'tonal.dart';
import 'ui.dart';
import 'ui_kit.dart';
import 'words.dart';
import 'wiktionary.dart';
import 'app_log.dart';

/// Meaning, pronunciation, synonyms and antonyms of the answer, from
/// the Wiktionary of the word's language. Shown after the game ends; every failure degrades to a
/// one-line note, since the game itself never depends on the network.
class WordInfoView extends StatefulWidget {
  const WordInfoView({
    super.key,
    required this.word,
    required this.language,
    this.showWord = false,
    this.trailing,
  });
  final String word;
  final Language language;

  /// Whether the word leads the pronunciation row (the end screen, where the
  /// word is named there and nowhere else).
  final bool showWord;

  /// At the right of that row: the bookmark that saves the word.
  final Widget? trailing;

  @override
  State<WordInfoView> createState() => _WordInfoViewState();
}

class _WordInfoViewState extends State<WordInfoView> {
  late final Future<WordInfo?> _future = Wiktionary.shared.lookup(
    widget.word,
    widget.language.code,
    widget.language.wikt,
  );

  /// The word and the bookmark on their own row, for while the entry loads and
  /// when there is none.
  Widget _row(BuildContext context, Widget below) {
    if (!widget.showWord && widget.trailing == null) return below;
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.showWord)
              Flexible(
                child: Text(
                  widget.word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: c.primary,
                  ),
                ),
              ),
            if (widget.trailing != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: widget.trailing,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        below,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WordInfo?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _row(context, const Caption('looking up in wiktionary…'));
        }
        final info = snap.data;
        if (snap.hasError) {
          return _row(context, const Caption('could not reach wiktionary'));
        }
        if (info == null || info.isEmpty) {
          return _row(
            context,
            const Caption('no wiktionary entry for this word'),
          );
        }
        return WordInfoBody(
          info: info,
          word: widget.showWord ? widget.word : null,
          saved: widget.trailing,
          underSense: (b, s) {
            final root = rootOfSense(s.text, widget.word);
            return root == null
                ? null
                : RootSenses(root: root, pos: b.pos, language: widget.language);
          },
        );
      },
    );
  }
}

/// An entry already in hand: the pronunciation (with its listen button), the
/// meanings by part of speech with their examples, the origin, synonyms and
/// antonyms. The end screen shows it for the answer ([WordInfoView]), and a
/// saved word shows its own copy.
class WordInfoBody extends StatefulWidget {
  const WordInfoBody({
    super.key,
    required this.info,
    this.underSense,
    this.saved,
    this.word,
  });
  final WordInfo info;

  /// The word, which leads the pronunciation row, before the pronunciation.
  final String? word;

  /// Shown under a meaning, if it gives something: the meaning of the root
  /// when the sense says it is a form of another word.
  final Widget? Function(PosBlock block, Sense sense)? underSense;

  /// Shown at the right of the pronunciation row (a saved word's date).
  final Widget? saved;

  @override
  State<WordInfoBody> createState() => _WordInfoBodyState();
}

class _WordInfoBodyState extends State<WordInfoBody> {
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
    } catch (e) {
      appLog.w(
        'word',
        'the pronunciation could not be played: ${e.runtimeType}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final info = widget.info;
    final dim = c.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.ipa.isNotEmpty ||
            info.audio != null ||
            widget.saved != null ||
            widget.word != null)
          _pronunciation(context, c, info),
        for (var i = 0; i < info.blocks.length; i++) ...[
          SectionLabel(_posLabel(info.blocks[i]), first: i == 0),
          GroupedList(
            rows: [
              for (var j = 0; j < info.blocks[i].senses.length; j++)
                _senseRow(
                  context,
                  c,
                  j + 1,
                  info.blocks[i],
                  info.blocks[i].senses[j],
                ),
            ],
          ),
        ],
        if (info.etymology.isNotEmpty) ...[
          const SectionLabel('origin'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              info.etymology,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: dim,
              ),
            ),
          ),
        ],
        if (info.synonyms.isNotEmpty) ...[
          const SectionLabel('synonyms'),
          _pills(info.synonyms, c.onSurface, tonesOf(context).s2),
        ],
        if (info.antonyms.isNotEmpty) ...[
          const SectionLabel('antonyms'),
          _pills(info.antonyms, c.onErrorContainer, c.errorContainer),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(info.url)),
            icon: TablerIcon('link', size: 18, color: c.onSurface),
            label: Text(linkLabelFor(info.url)),
          ),
        ),
      ],
    );
  }

  /// The pronunciation (dim, 16) with the round listen button, and the saved
  /// info at the right of the same row.
  Widget _pronunciation(BuildContext context, ColorScheme c, WordInfo info) {
    final saved = widget.saved;
    // the word, the pronunciation and the listen button on the left (they take
    // the room that is left), what is saved of it (the bookmark, the date) at
    // the right end
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (widget.word != null) ...[
                Flexible(
                  child: Text(
                    widget.word!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: c.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (info.ipa.isNotEmpty)
                Flexible(
                  child: Text(
                    info.ipa.join('   '),
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 16),
                  ),
                ),
              if (info.audio != null) ...[
                const SizedBox(width: 12),
                IconButton(
                  key: const ValueKey('word-listen'),
                  tooltip: 'listen',
                  style: IconButton.styleFrom(
                    backgroundColor: tonesOf(context).s1,
                    shape: const CircleBorder(),
                    fixedSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                  color: c.primary,
                  icon: const Icon(Icons.volume_up_outlined, size: 22),
                  onPressed: () => _play(info.audio!),
                ),
              ],
            ],
          ),
        ),
        if (saved != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: FittedBox(fit: BoxFit.scaleDown, child: saved),
          ),
      ],
    );
  }

  /// The section label of a part of speech: the part, then gender and forms.
  String _posLabel(PosBlock b) =>
      [b.pos, b.gender, b.forms].where((s) => s.isNotEmpty).join('  ');

  /// One numbered sense: a small round badge, the labels in the warm colour
  /// and the gloss, the examples dim and italic under it, and the root's
  /// meanings (if any) last.
  GroupRow _senseRow(
    BuildContext context,
    ColorScheme c,
    int n,
    PosBlock b,
    Sense s,
  ) {
    final examples = s.examples;
    return GroupRow(
      crossAxisStart: true,
      leading: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tonesOf(context).s3,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$n',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: c.onSurface,
          ),
        ),
      ),
      title: Text.rich(
        TextSpan(
          children: [
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
        style: const TextStyle(fontWeight: FontWeight.w400),
      ),
      subtitle: examples.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in examples)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      e.translation.isEmpty
                          ? e.text
                          : '${e.text}\n${e.translation}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
      below: widget.underSense?.call(b, s),
    );
  }

  /// Related words as tonal pills, 36 high and fully round, no edge.
  Widget _pills(List<String> words, Color fg, Color bg) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final w in words)
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(w, style: TextStyle(fontSize: 14, color: fg)),
        ),
    ],
  );
}
