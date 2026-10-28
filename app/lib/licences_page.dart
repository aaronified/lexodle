import 'dart:math';

import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter/material.dart';

import 'ui.dart';

/// One package (or bundled thing) and the licence texts that name it.
class PackageLicence {
  const PackageLicence(this.name, this.texts);
  final String name;
  final List<String> texts;

  /// The letter it is filed under: its first letter, upper case, or `#` for
  /// a name that does not start with one.
  String get initial {
    if (name.isEmpty) return '#';
    final c = name[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
  }
}

/// Every licence the app knows (Flutter's own, the packages', and what
/// registerLicences adds), by the thing it names, sorted by name.
Future<List<PackageLicence>> loadLicences() async {
  final byName = <String, List<String>>{};
  await for (final e in LicenseRegistry.licenses) {
    final text = [for (final p in e.paragraphs) p.text].join('\n\n');
    for (final name in e.packages) {
      (byName[name] ??= []).add(text);
    }
  }
  final out = [for (final e in byName.entries) PackageLicence(e.key, e.value)]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// The about text and the licences: a search box, the packages in alphabetical
/// order with a letter heading each, and a strip of letters down the right edge
/// to jump by (touch it and slide, as in a contacts list).
class LicencesPage extends StatefulWidget {
  const LicencesPage({super.key, this.about = '', this.load});

  /// What the app says about itself, shown above the list.
  final String about;

  /// How the licences are read (tests give their own).
  final Future<List<PackageLicence>> Function()? load;

  @override
  State<LicencesPage> createState() => _LicencesPageState();
}

class _LicencesPageState extends State<LicencesPage> {
  static const _tileH = 56.0, _headH = 34.0;

  final _scroll = ScrollController();
  final _search = TextEditingController();
  List<PackageLicence>? _all;
  String _query = '';
  String? _bubble; // the letter shown while the strip is touched

  @override
  void initState() {
    super.initState();
    (widget.load ?? loadLicences)().then((l) {
      if (mounted) setState(() => _all = l);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  List<PackageLicence> get _shown {
    final all = _all ?? const [];
    final q = _query.trim().toLowerCase();
    return q.isEmpty
        ? all
        : [
            for (final p in all)
              if (p.name.toLowerCase().contains(q)) p,
          ];
  }

  /// The rows of the list: a heading for each letter, then its packages.
  List<Object> _rows(List<PackageLicence> shown) {
    final rows = <Object>[];
    String? last;
    for (final p in shown) {
      if (p.initial != last) {
        last = p.initial;
        rows.add(last);
      }
      rows.add(p);
    }
    return rows;
  }

  double _offsetOf(List<Object> rows, String letter) {
    var y = 0.0;
    for (final r in rows) {
      if (r is String) {
        if (r == letter) return y;
        y += _headH;
      } else {
        y += _tileH;
      }
    }
    return y;
  }

  void _jump(List<Object> rows, String letter) {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(
      min(_offsetOf(rows, letter), _scroll.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    final shown = _shown;
    final rows = _rows(shown);
    final letters = [
      for (final r in rows)
        if (r is String) r,
    ];

    Widget list() {
      if (_all == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (shown.isEmpty) {
        return Center(
          child: Text(
            'no licence matches "$_query"',
            key: const ValueKey('licences-empty'),
            style: dim,
          ),
        );
      }
      return ListView.builder(
        key: const ValueKey('licences-list'),
        controller: _scroll,
        padding: const EdgeInsets.only(right: 28, bottom: 24),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final r = rows[i];
          if (r is String) {
            return SizedBox(
              key: ValueKey('licence-header-$r'),
              height: _headH,
              child: Padding(
                padding: const EdgeInsets.only(left: 19, top: 12),
                child: Text(
                  r,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.primary,
                  ),
                ),
              ),
            );
          }
          final p = r as PackageLicence;
          return SizedBox(
            height: _tileH,
            child: InkWell(
              key: ValueKey('licence-tile-${p.name}'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => _LicenceText(p)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    Widget strip() => LayoutBuilder(
      builder: (context, box) {
        String at(double dy) {
          final i = (dy / box.maxHeight * letters.length).floor();
          return letters[i.clamp(0, letters.length - 1)];
        }

        void touch(double dy) {
          if (letters.isEmpty) return;
          final letter = at(dy);
          setState(() => _bubble = letter);
          _jump(rows, letter);
        }

        // raw pointer events, so the letter shows the moment a finger is down
        // and follows it, with no wait to tell a tap from a drag
        void release() => setState(() => _bubble = null);
        return Listener(
          key: const ValueKey('licences-index'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => touch(e.localPosition.dy),
          onPointerMove: (e) => touch(e.localPosition.dy),
          onPointerUp: (_) => release(),
          onPointerCancel: (_) => release(),
          child: SizedBox(
            width: 28,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final l in letters)
                  Text(
                    l,
                    key: ValueKey('licences-index-$l'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: l == _bubble
                          ? c.primary
                          : c.onSurface.withValues(alpha: .6),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('about and licences')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.about.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(19, 0, 19, 10),
                    child: Text(
                      widget.about,
                      key: const ValueKey('about-text'),
                      style: dim,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(19, 0, 19, 6),
                  child: TextField(
                    key: const ValueKey('licences-search'),
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'search the licences',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              key: const ValueKey('licences-search-clear'),
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(19, 0, 19, 4),
                  child: Text(
                    _all == null
                        ? 'reading the licences…'
                        : '${shown.length} of ${_all!.length}',
                    key: const ValueKey('licences-count'),
                    style: dim,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      list(),
                      if (letters.isNotEmpty)
                        Positioned(right: 0, top: 4, bottom: 4, child: strip()),
                      if (_bubble != null)
                        Center(
                          child: Container(
                            key: const ValueKey('licences-bubble'),
                            width: 72,
                            height: 72,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _bubble!,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: c.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The licence text of one package.
class _LicenceText extends StatelessWidget {
  const _LicenceText(this.p);
  final PackageLicence p;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('licence-text'),
          padding: const EdgeInsets.fromLTRB(19, 8, 19, 32),
          children: [
            for (final t in p.texts) ...[
              SelectableText(
                t,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const Divider(height: 32),
            ],
          ],
        ),
      ),
    );
  }
}
