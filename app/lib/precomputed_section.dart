import 'package:flutter/material.dart';

import 'main.dart';
import 'precomputed.dart';
import 'precomputed_local.dart';
import 'ui.dart';
import 'words.dart';

/// "12 MB", "340 KB": a size as a person reads it.
String sizeText(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / 1024 / 1024).toStringAsFixed(bytes >= 10 * 1024 * 1024 ? 0 : 1)} MB'
    : '${(bytes / 1024).ceil()} KB';

/// The settings section for the precomputed openings: the first guess of every
/// list, scored ahead, so a game and the learn pages do not wait for it. They
/// are downloaded from the repository, for the lists the player chooses, with
/// the size shown first.
class PrecomputedSection extends StatefulWidget {
  const PrecomputedSection({super.key});

  @override
  State<PrecomputedSection> createState() => _PrecomputedSectionState();
}

class _PrecomputedSectionState extends State<PrecomputedSection> {
  PrecomputedManifest? _manifest;
  bool _checked = false;
  Map<String, String> _have = {};
  String _language = '';
  String? _busy;
  double _done = 0;
  String? _note;

  @override
  void initState() {
    super.initState();
    _have = PrecomputedLocal.downloaded();
    _load();
  }

  Future<void> _load() async {
    final langs = await WordBank.languages();
    final m = await fetchPrecomputedManifest();
    if (!mounted) return;
    final mine = langs.where((l) => l.code == appState.lang);
    setState(() {
      _manifest = m;
      _checked = true;
      _language = mine.isEmpty ? appState.lang : mine.first.name.toLowerCase();
    });
  }

  Future<void> _download(String key, List<String> lists) async {
    final m = _manifest;
    if (m == null || _busy != null) return;
    setState(() {
      _busy = key;
      _done = 0;
      _note = null;
    });
    final ok = await PrecomputedLocal.download(
      m,
      lists,
      onProgress: (d) {
        if (mounted) setState(() => _done = d);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = null;
      _have = PrecomputedLocal.downloaded();
      _note = ok ? 'downloaded' : 'some files could not be fetched: try again';
    });
  }

  void _remove() {
    PrecomputedLocal.remove();
    setState(() {
      _have = {};
      _note = 'removed';
    });
  }

  Widget _row(String key, String label, List<String> lists) {
    final m = _manifest!;
    final bytes = lists.fold<int>(0, (t, l) => t + (m.lists[l] ?? 0));
    if (bytes == 0) return const SizedBox.shrink();
    final done = lists.every((l) => _have[l] == m.generated || m.of(l).isEmpty);
    final working = _busy == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          key: ValueKey('precomputed-$key'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            shape: const RoundedRectangleBorder(),
            alignment: Alignment.centerLeft,
          ),
          onPressed: _busy != null || done ? null : () => _download(key, lists),
          child: Text(
            working
                ? '$label · ${(100 * _done).round()}%'
                : done
                ? '$label · ${sizeText(bytes)} · downloaded'
                : '$label · download ${sizeText(bytes)}',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    final m = _manifest;
    final onDisk = PrecomputedLocal.size();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'the first guess of every list, scored ahead: nothing waits.',
          style: dim,
        ),
        const SizedBox(height: 8),
        if (!_checked)
          Text('checking what there is…', style: dim)
        else if (m == null)
          Text(
            'nothing to download: offline, or none made yet.',
            key: const ValueKey('precomputed-none'),
            style: dim,
          )
        else ...[
          _row('mine', _language, [appState.lang]),
          _row('equations', 'equations', const ['equations']),
          _row('places', 'places', const ['places']),
          _row('all', 'every list', m.lists.keys.toList()),
        ],
        if (_note != null)
          Text(_note!, key: const ValueKey('precomputed-note'), style: dim),
        if (onDisk > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('${sizeText(onDisk)} on this device', style: dim),
              ),
              TextButton(
                key: const ValueKey('precomputed-remove'),
                onPressed: _busy != null ? null : _remove,
                child: const Text('remove'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
