import 'package:flutter/material.dart';

import 'app_log.dart';
import 'main.dart';
import 'profile.dart';
import 'ui.dart';

/// The avatar's background colours, from the colour scheme: the green, a softer
/// green, the stone, the ink.
Color profileBg(ColorScheme c, int bg) => switch (bg) {
  1 => Color.alphaBlend(c.secondary.withValues(alpha: 0.55), c.surface),
  2 => c.surfaceContainerHighest,
  3 => c.onSurface,
  _ => c.secondary,
};

/// The readable colour for the icon on [profileBg].
Color profileFg(ColorScheme c, int bg) =>
    ThemeData.estimateBrightnessForColor(profileBg(c, bg)) == Brightness.dark
    ? (c.brightness == Brightness.dark ? c.onSurface : c.surface)
    : (c.brightness == Brightness.dark ? c.surface : c.onSurface);

/// A round avatar: the icon of [p] on its coloured circle.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar(this.p, {super.key, this.size = 32});
  final Profile p;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: profileBg(c, p.bg),
      ),
      child: TablerIcon(p.icon, size: size * 0.55, color: profileFg(c, p.bg)),
    );
  }
}

/// Opens the sheet where the player picks name, icon and colour. Everything
/// applies at once. A photo comes in a later version.
Future<void> showProfileSheet(BuildContext context) async {
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => const _ProfileSheet(),
    );
  } catch (e) {
    appLog.w('profile', 'sheet failed ${e.runtimeType}');
  }
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet();

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  final _name = TextEditingController(text: appState.profile.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set({String? name, String? icon, int? bg}) {
    final p = appState.profile;
    appState.setProfile(
      Profile(name: name ?? p.name, icon: icon ?? p.icon, bg: bg ?? p.bg),
    );
  }

  Widget _ring(Widget child, bool on, ColorScheme c) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: on ? c.primary : const Color(0x00000000),
        width: 2,
      ),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final p = appState.profile;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(19, 8, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'your name',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(19, 8, 19, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: ProfileAvatar(p, size: 84)),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('profile-name'),
                        controller: _name,
                        maxLength: profileNameMax,
                        onChanged: (v) => _set(name: v),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Caption('pick an icon'),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (final i in profileIcons)
                            InkWell(
                              key: ValueKey('profile-icon-$i'),
                              customBorder: const CircleBorder(),
                              onTap: () => _set(icon: i),
                              child: _ring(
                                Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.surfaceContainerHighest,
                                  ),
                                  child: TablerIcon(
                                    i,
                                    size: 26,
                                    color: c.onSurface,
                                  ),
                                ),
                                p.icon == i,
                                c,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Caption('colour'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var b = 0; b < profileColours; b++)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                key: ValueKey('profile-bg-$b'),
                                customBorder: const CircleBorder(),
                                onTap: () => _set(bg: b),
                                child: _ring(
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: profileBg(c, b),
                                    ),
                                  ),
                                  p.bg == b,
                                  c,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
