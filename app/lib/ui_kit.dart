import 'package:flutter/material.dart';

import 'app_log.dart';
import 'settings_button.dart';
import 'tonal.dart';
import 'ui.dart';

/// The pieces every screen is built from, so the four rules of the look (space
/// before containment, one edge language, a control rhythm, radius by role) live
/// in one place. Colours come from the theme: the scheme and [AppTones].

/// The height of the row of a page's header: the title (or the tabs), the small
/// info, the settings cog. It is the same on every page, so the cog never moves.
const headerRowHeight = 48.0;

/// The top of a page: the title on the left, a small dim [info] before the
/// settings cog (the cog is left out with [settings] false), and a back arrow
/// when [back] is set. 16 pixels from the edges, [headerRowHeight] high. [title]
/// replaces the text title with any widget (the tabs of the words page).
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.text,
    this.title,
    this.info,
    this.back = false,
    this.onBack,
    this.settings = true,
    this.actions = const [],
  }) : assert(text != null || title != null);

  final String? text;
  final Widget? title;
  final Widget? info;
  final bool back;
  final VoidCallback? onBack;
  final bool settings;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        height: headerRowHeight,
        child: Row(
          children: [
            if (back)
              Transform.translate(
                offset: const Offset(-12, 0),
                child: IconButton(
                  key: const ValueKey('header-back'),
                  tooltip: 'back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                ),
              ),
            Expanded(
              child:
                  title ??
                  Text(
                    text!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ),
            if (info != null) ...[const SizedBox(width: 8), info!],
            ...actions,
            if (settings) const SettingsButton(),
          ],
        ),
      ),
    );
  }
}

/// The small dim text beside a title: a date, a language and length.
class HeaderInfo extends StatelessWidget {
  const HeaderInfo(this.text, {super.key, this.leading});
  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Text(text, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
      ],
    );
  }
}

/// A label that opens a section: dim, small, with space above it. Sections are
/// told apart by this space and the label, not by a rule.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.first = false});
  final String text;

  /// The first label of a page has less space above it.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(2, first ? 12 : 28, 2, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1,
          color: c.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A square tile with an icon in it: 40 (or 48 with [big]) at radius 10 on the
/// tone above the group, the icon in [color] (the accent by default).
class TonalTile extends StatelessWidget {
  const TonalTile(
    this.icon, {
    super.key,
    this.big = false,
    this.color,
    this.fill,
  });

  /// A Tabler icon name from assets/icons.
  final String icon;
  final bool big;
  final Color? color;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final size = big ? 48.0 : 40.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill ?? tonesOf(context).s2,
        borderRadius: BorderRadius.circular(radiusElement),
      ),
      child: Center(
        child: TablerIcon(icon, size: big ? 26 : 22, color: color ?? c.primary),
      ),
    );
  }
}

/// One row of a [GroupedList]: an optional leading widget (a [TonalTile]), a
/// title and a line under it, and a trailing widget; with an [onTap] it shows a
/// chevron unless [chevron] is false.
class GroupRow {
  const GroupRow({
    this.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.crossAxisStart = false,
    this.below,
  });

  final Key? key;
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  /// Aligns the row to the top, for a row with several lines.
  final bool crossAxisStart;

  /// More content under the title and its line (a bar, dots).
  final Widget? below;
}

/// A group of rows on one tonal surface, told apart by 2 pixels of page colour,
/// not by lines: the outer corners are round (the container radius) and the
/// inner ones nearly square, so the corners stay concentric.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.rows});
  final List<GroupRow> rows;

  static const _inner = Radius.circular(4);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tones = tonesOf(context);
    const outer = Radius.circular(radiusContainer);
    final n = rows.length;
    return Column(
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _row(
            context,
            rows[i],
            BorderRadius.only(
              topLeft: i == 0 ? outer : _inner,
              topRight: i == 0 ? outer : _inner,
              bottomLeft: i == n - 1 ? outer : _inner,
              bottomRight: i == n - 1 ? outer : _inner,
            ),
            tones,
            c,
          ),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context,
    GroupRow r,
    BorderRadius radius,
    AppTones tones,
    ColorScheme c,
  ) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          crossAxisAlignment: r.crossAxisStart
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (r.leading != null) ...[r.leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    child: r.title,
                  ),
                  if (r.subtitle != null)
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: c.onSurfaceVariant,
                      ),
                      child: r.subtitle!,
                    ),
                  if (r.below != null) r.below!,
                ],
              ),
            ),
            if (r.trailing != null) ...[
              const SizedBox(width: 8),
              DefaultTextStyle.merge(
                style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
                child: r.trailing!,
              ),
            ],
            if (r.onTap != null && r.chevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: c.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
    return Material(
      key: r.key,
      color: tones.s1,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: r.onTap == null ? body : InkWell(onTap: r.onTap, child: body),
    );
  }
}

/// A row of big numbers over small labels, on one tonal card: games, won,
/// streak, best.
class StatsStrip extends StatelessWidget {
  const StatsStrip(this.stats, {super.key, this.keyPrefix});

  /// Each: the number, its label, and a colour for the number (or null).
  final List<(String, String, Color?)> stats;

  /// When given, each number has the key '$keyPrefix-$label' (the tests find it).
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final (number, label, color) in stats)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  key: keyPrefix == null ? null : ValueKey('$keyPrefix-$label'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A card: one thing that is a group (a streak, some stats, a goal) on a tonal
/// fill at the container radius, with no edge.
class TonalCard extends StatelessWidget {
  const TonalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tonesOf(context).s1,
        borderRadius: BorderRadius.circular(radiusContainer),
      ),
      child: child,
    );
  }
}

/// One thing to choose in a [ChoiceSlider]: its [value], the [label] shown, and
/// an icon (a Tabler name, drawn in the accent) or any [leading] widget (a flag).
class ChoiceItem<T> {
  const ChoiceItem({
    required this.value,
    required this.label,
    this.icon,
    this.leading,
  });

  final T value;
  final String label;
  final String? icon;
  final Widget? leading;
}

/// The one control for choosing one of several things (a mode, a language, a
/// medal): an arrow either side, the name with its icon between them, dots under
/// it, and a swipe. It does not wrap round: the arrow of an end is dim. [id] names
/// the keys: the slider itself, and `$id-prev`, `$id-next` and `$id-dots`.
class ChoiceSlider<T> extends StatefulWidget {
  const ChoiceSlider({
    super.key,
    required this.id,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.compact = false,
    this.dots = true,
    this.onTapName,
  });

  /// Called when the name in the middle is tapped (the free play strip starts a
  /// game with it); null leaves the middle as plain text.
  final VoidCallback? onTapName;

  final String id;
  final List<ChoiceItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  /// 48 high at the element radius, for a row beside another control.
  final bool compact;

  /// Whether the dots show under the slider.
  final bool dots;

  @override
  State<ChoiceSlider<T>> createState() => _ChoiceSliderState<T>();
}

/// The slider follows the finger: the name moves with the drag and the next
/// one comes in from the side; on release it settles on the next choice when
/// the drag went far or fast enough, and otherwise slides back. At an end
/// the drag is resisted.
class _ChoiceSliderState<T> extends State<ChoiceSlider<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  double _dx = 0;
  double _width = 0;
  Animation<double>? _tween;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      final t = _tween;
      if (t != null) setState(() => _dx = t.value);
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  int get _at {
    final i = widget.items.indexWhere((x) => x.value == widget.selected);
    return i < 0 ? 0 : i;
  }

  bool _has(int by) {
    final to = _at + by;
    return to >= 0 && to < widget.items.length;
  }

  void _go(int by) {
    if (!_has(by)) return;
    widget.onChanged(widget.items[_at + by].value);
  }

  void _start(DragStartDetails d) {
    _settle.stop();
    _tween = null;
  }

  void _update(DragUpdateDetails d) {
    // an end of the list resists: the name follows only a third of the way
    final delta = d.delta.dx;
    final toward = delta < 0 ? 1 : -1;
    final blocked =
        (_dx == 0 && !_has(toward)) ||
        (_dx < 0 && !_has(1)) ||
        (_dx > 0 && !_has(-1));
    setState(() {
      _dx += blocked ? delta / 3 : delta;
      final w = _width <= 0 ? 200.0 : _width;
      _dx = _dx.clamp(-w, w);
    });
  }

  void _end(DragEndDetails d) {
    final w = _width <= 0 ? 200.0 : _width;
    final v = d.primaryVelocity ?? 0;
    var by = 0;
    if (_dx.abs() > w * 0.3 || v.abs() > 300) {
      // the direction of the drag, or of the flick when it goes the other way
      final dir = v.abs() > 300 ? (v < 0 ? 1 : -1) : (_dx < 0 ? 1 : -1);
      if (_has(dir)) by = dir;
    }
    final target = by == 0 ? 0.0 : -by * w;
    _tween = Tween<double>(
      begin: _dx,
      end: target,
    ).animate(CurvedAnimation(parent: _settle, curve: Curves.easeOut));
    _settle.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _tween = null;
      // the choice is made when the name has come to rest; the new name is
      // drawn at 0 where the one that slid in stopped, so nothing jumps
      if (by != 0) {
        try {
          _go(by);
        } catch (e) {
          appLog.w('slider', 'choice failed ${e.runtimeType}');
        }
      }
      setState(() => _dx = 0);
    });
  }

  Widget _name(ChoiceItem<T> item, ColorScheme c, {bool tap = false}) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (item.icon != null) ...[
          TablerIcon(item.icon!, size: 22, color: c.primary),
          const SizedBox(width: 8),
        ] else if (item.leading != null) ...[
          item.leading!,
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    if (!tap) return row;
    return InkWell(
      key: ValueKey('${widget.id}-name'),
      borderRadius: BorderRadius.circular(radiusElement),
      onTap: widget.onTapName,
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tones = tonesOf(context);
    final items = widget.items;
    final id = widget.id;
    if (items.isEmpty) return const SizedBox.shrink();
    final at = _at;
    final item = items[at];
    Widget arrow(Key key, IconData icon, String label, int by, bool on) {
      // (no tooltip: a phone has no hover, and a long press is hidden)
      return Semantics(
        button: true,
        label: label,
        enabled: on,
        excludeSemantics: true,
        child: SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            key: key,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 22),
            color: c.onSurface,
            disabledColor: tones.s3,
            onPressed: on ? () => _go(by) : null,
          ),
        ),
      );
    }

    final bar = Container(
      key: ValueKey(id),
      height: widget.compact ? 48 : 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: tones.s1,
        borderRadius: BorderRadius.circular(
          widget.compact ? radiusElement : radiusContainer,
        ),
      ),
      child: Row(
        children: [
          arrow(
            ValueKey('$id-prev'),
            Icons.chevron_left,
            'previous',
            -1,
            at > 0,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                _width = box.maxWidth;
                final w = box.maxWidth;
                return ClipRect(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_dx > 0 && at > 0)
                        Transform.translate(
                          offset: Offset(_dx - w, 0),
                          child: SizedBox(
                            width: w,
                            child: _name(items[at - 1], c),
                          ),
                        ),
                      if (_dx < 0 && at < items.length - 1)
                        Transform.translate(
                          offset: Offset(_dx + w, 0),
                          child: SizedBox(
                            width: w,
                            child: _name(items[at + 1], c),
                          ),
                        ),
                      Transform.translate(
                        offset: Offset(_dx, 0),
                        child: SizedBox(
                          width: w,
                          height: double.infinity,
                          child: _name(item, c, tap: true),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          arrow(
            ValueKey('$id-next'),
            Icons.chevron_right,
            'next',
            1,
            at < items.length - 1,
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: 'choose',
      value: item.label,
      increasedValue: at < items.length - 1 ? items[at + 1].label : null,
      decreasedValue: at > 0 ? items[at - 1].label : null,
      onIncrease: at < items.length - 1 ? () => _go(1) : null,
      onDecrease: at > 0 ? () => _go(-1) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _start,
        onHorizontalDragUpdate: _update,
        onHorizontalDragEnd: _end,
        onHorizontalDragCancel: () {
          if (_dx != 0) _end(DragEndDetails());
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bar,
            if (widget.dots && items.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                key: ValueKey('$id-dots'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == at ? c.onSurface : tones.s3,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The bar at the foot of the shell: flat, on the page colour, a hairline above
/// it; the tab on show is bold with a 2 pixel line in the accent on the hairline.
/// [icons] gives each tab its outlined and its filled icon.
class FlatTabBar extends StatelessWidget {
  const FlatTabBar({
    super.key,
    required this.ids,
    required this.icons,
    required this.selected,
    required this.onSelect,
  });

  final List<String> ids;
  final Map<String, (IconData, IconData)> icons;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < ids.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: ids[i],
                    excludeSemantics: true,
                    child: InkWell(
                      key: ValueKey('tab-${ids[i]}-button'),
                      onTap: () => onSelect(i),
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          if (i == selected)
                            Positioned(
                              top: -1,
                              left: 14,
                              right: 14,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: c.primary,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Column(
                              children: [
                                Icon(
                                  i == selected
                                      ? icons[ids[i]]!.$2
                                      : icons[ids[i]]!.$1,
                                  size: 24,
                                  color: i == selected
                                      ? c.onSurface
                                      : c.onSurfaceVariant,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ids[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: .5,
                                    fontWeight: i == selected
                                        ? FontWeight.w700
                                        : null,
                                    color: i == selected
                                        ? c.onSurface
                                        : c.onSurfaceVariant,
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
            ],
          ),
        ),
      ),
    );
  }
}
