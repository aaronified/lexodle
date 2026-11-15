import 'dart:math';

import 'package:flutter/material.dart';

import 'logic.dart';
import 'ui.dart';

/// How a guess splits the words that fit: one bar per way the game can colour
/// it (a group), tallest first, each as high as the words left in it. The bars
/// keep their width and the strip scrolls sideways when they do not all fit.
/// [highlight] is the code of the colouring (see markCode) to light.
class SplitPlot extends StatefulWidget {
  const SplitPlot({
    super.key,
    required this.word,
    required this.groups,
    required this.average,
    required this.length,
    this.highlight,
    this.onUse,
    this.label,
    this.idle = 'use it, then tap its tiles to see where the game puts you',
  });

  final String word;
  final List<(int, int)> groups;

  /// sum(count^2) / total: the words left on average.
  final double average;
  final int? highlight;
  final int length;
  final VoidCallback? onUse;
  final String idle;

  /// Says in words which colouring a group is, in place of the row of coloured
  /// squares (for the blind counts, whose groups are not colours).
  final String Function(int code)? label;

  @override
  State<SplitPlot> createState() => _SplitPlotState();
}

class _SplitPlotState extends State<SplitPlot> {
  static const _barW = 5.0, _gap = 2.0, _height = 72.0, _edge = 8.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(SplitPlot old) {
    super.didUpdateWidget(old);
    if (old.word != widget.word) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _reveal();
    } else if (old.highlight != widget.highlight) {
      _reveal();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _indexOfHighlight() {
    final h = widget.highlight;
    if (h == null) return -1;
    return widget.groups.indexWhere((g) => g.$1 == h);
  }

  /// Scrolls the lit bar to the middle when it is out of the window, or within
  /// [_edge] of its edge.
  void _reveal() {
    final i = _indexOfHighlight();
    if (i < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final p = _scroll.position;
      final x = i * (_barW + _gap);
      if (x >= p.pixels + _edge &&
          x + _barW <= p.pixels + p.viewportDimension - _edge) {
        return;
      }
      final to = (x + _barW / 2 - p.viewportDimension / 2).clamp(
        0.0,
        p.maxScrollExtent,
      );
      if (to == p.pixels) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(to);
      } else {
        _scroll.animateTo(
          to,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    final groups = widget.groups;
    final top = groups.isEmpty ? 1 : groups.first.$2;
    final hl = widget.highlight;
    final lit = _indexOfHighlight();
    final litCount = lit < 0 ? 0 : groups[lit].$2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.fromBorderSide(hairline(c)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: widget.word,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' · ${groups.length} '
                            '${groups.length == 1 ? 'group' : 'groups'} · '
                            '${widget.average.toStringAsFixed(1)} left on average',
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (widget.onUse != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const ValueKey('plot-use'),
                  onPressed: widget.onUse,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    side: hairline(c),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('use'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _height,
            child: SingleChildScrollView(
              key: const ValueKey('plot-scroll'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < groups.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Container(
                      key: ValueKey(
                        i == lit ? 'plot-bar-hl' : 'plot-bar-${groups[i].$1}',
                      ),
                      width: _barW,
                      height: max(3.0, groups[i].$2 / top * _height),
                      decoration: BoxDecoration(
                        color: i == lit
                            ? c.secondary
                            : c.onSurface.withValues(alpha: .5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
            child: hl == null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.idle,
                      style: TextStyle(fontSize: 12, color: dim),
                    ),
                  )
                : Row(
                    children: [
                      if (widget.label != null)
                        Text(
                          '${widget.label!(hl)} · ',
                          style: TextStyle(fontSize: 12, color: dim),
                        )
                      else
                        for (final m in _marksOf(hl)) ...[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: markColors(c, m).$1,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$litCount ${litCount == 1 ? 'word' : 'words'} '
                          'if the game shows this',
                          style: TextStyle(fontSize: 12, color: dim),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            'each bar is the words left for one colouring, not the bits of '
            'information that the review plots.',
            style: TextStyle(fontSize: 10, color: dim),
          ),
        ],
      ),
    );
  }

  /// The marks of a pattern code, first tile first.
  List<Mark> _marksOf(int code) {
    final out = List.filled(widget.length, Mark.absent);
    var v = code;
    for (var i = widget.length - 1; i >= 0; i--) {
      out[i] = Mark.values[v % 3];
      v ~/= 3;
    }
    return out;
  }
}
