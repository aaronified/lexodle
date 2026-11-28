import 'package:flutter/material.dart';

import 'tonal.dart';
import 'ui.dart' show radiusSheet;
import 'ui_kit.dart';

/// The route of a settings or history page: a sheet that rises from the bottom
/// to just below the app's top bar. The top bar stays on show and live (a tap
/// on it reaches the page under, so the language pill and the cog still work);
/// the page under is dimmed as the sheet rises. A sheet
/// opened on top of another (reminders from settings) has no dimming of its own.
class PageSheetRoute<T> extends PopupRoute<T> {
  PageSheetRoute({required this.builder, super.settings});

  /// Builds the page, which draws its own [PageSheet] frame.
  final WidgetBuilder builder;

  static int _open = 0;
  late final int _depth;

  @override
  void install() {
    _depth = _open++;
    super.install();
  }

  @override
  void dispose() {
    _open--;
    super.dispose();
  }

  /// The sheet follows the finger on its handle: [dy] down moves it that far
  /// ([height] is the sheet's own).
  void dragUpdate(double dy, double height) {
    final c = controller;
    if (c == null || height <= 0) return;
    c.value = (c.value - dy / height).clamp(0.0, 1.0);
  }

  /// The finger lifts: a fling down or a sheet pulled more than a third of the
  /// way closes it, any other settles back open.
  void dragEnd(double velocity) {
    final c = controller;
    if (c == null) return;
    if (velocity > 700 || c.value < 0.66) {
      if (isCurrent) navigator?.pop();
    } else {
      c.forward();
    }
  }

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => 'close';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  // no barrier over the whole screen: it would absorb every tap on the top bar
  @override
  Widget buildModalBarrier() => const SizedBox.shrink();

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    // the sheet starts where the top bar ends
    final top = MediaQuery.paddingOf(context).top + topBarInset - 8;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          top: top,
          child: Stack(
            children: [
              if (_depth == 0)
                Positioned.fill(
                  child: FadeTransition(
                    opacity: curved,
                    child: GestureDetector(
                      key: const ValueKey('sheet-scrim'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.maybePop(context),
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.scrim
                            .withValues(alpha: .55),
                      ),
                    ),
                  ),
                ),
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The frame of a sheet page: its own top bar (the [title], any [trailing]
/// buttons, a close button) over [child], which fills the rest and scrolls.
/// Radius 28 at the top, the page colour, a handle.
class PageSheet extends StatelessWidget {
  const PageSheet({
    super.key,
    required this.title,
    required this.child,
    this.trailing = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) => _frame(context, c, box.maxHeight),
    );
  }

  Widget _frame(BuildContext context, ColorScheme c, double height) {
    return Material(
      color: c.surface,
      elevation: 16,
      shadowColor: c.shadow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
      ),
      clipBehavior: Clip.antiAlias,
      // a Scaffold of its own: a toast shown from a sheet appears on the sheet,
      // not behind it, and the sheet rises above the keyboard
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // the handle, drawn small, with a generous target round it that
                  // is not drawn: a drag down on it pulls the sheet away
                  _Handle(color: tonesOf(context).s3, sheetHeight: height),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(19, 0, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ...trailing,
                        IconButton(
                          key: const ValueKey('sheet-close'),
                          tooltip: 'close',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The handle of a sheet: 36 by 4, in a target the width of the sheet and 44
/// high. Dragging it moves the sheet ([PageSheetRoute.dragUpdate]); where there
/// is no such route (the frame shown alone) it does nothing.
class _Handle extends StatelessWidget {
  const _Handle({required this.color, required this.sheetHeight});
  final Color color;

  /// The height of the sheet, what a drag is measured against.
  final double sheetHeight;

  @override
  Widget build(BuildContext context) {
    PageSheetRoute<dynamic>? route() {
      final r = ModalRoute.of(context);
      return r is PageSheetRoute ? r : null;
    }

    return GestureDetector(
      key: const ValueKey('sheet-handle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => route()?.dragUpdate(d.delta.dy, sheetHeight),
      onVerticalDragEnd: (d) => route()?.dragEnd(d.velocity.pixelsPerSecond.dy),
      onVerticalDragCancel: () => route()?.dragEnd(0),
      child: SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
