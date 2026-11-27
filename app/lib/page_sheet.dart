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
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tonesOf(context).s3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(19, 4, 8, 8),
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
