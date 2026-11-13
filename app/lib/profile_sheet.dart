import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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

/// A round avatar: the photo of [p], or its icon on a coloured circle.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar(this.p, {super.key, this.size = 32});
  final Profile p;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final icon = TablerIcon(
      p.icon,
      size: size * 0.55,
      color: profileFg(c, p.bg),
    );
    final photo = p.photo;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: profileBg(c, p.bg),
      ),
      child: photo == null || kIsWeb
          ? icon
          : Image.file(
              File(photo),
              key: const ValueKey('profile-photo'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => icon,
            ),
    );
  }
}

/// Opens the sheet where the player picks name, icon and colour. Everything
/// applies at once. [pick] opens the gallery (replaceable in tests) and
/// [photoSupported] is false where there is no file path (the web).
Future<void> showProfileSheet(
  BuildContext context, {
  ProfilePhotoPicker pick = pickProfilePhoto,
  bool photoSupported = !kIsWeb,
  Future<Directory> Function() docsDir = getApplicationDocumentsDirectory,
}) async {
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => _ProfileSheet(
        pick: pick,
        photoSupported: photoSupported,
        docsDir: docsDir,
      ),
    );
  } catch (e) {
    appLog.w('profile', 'sheet failed ${e.runtimeType}');
  }
}

/// Opens the gallery and returns the path of the chosen picture, or null.
typedef ProfilePhotoPicker = Future<String?> Function();

/// The default picker: the gallery, at most 512 pixels, quality 80.
Future<String?> pickProfilePhoto() async {
  final f = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );
  return f?.path;
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({
    required this.pick,
    required this.photoSupported,
    required this.docsDir,
  });
  final ProfilePhotoPicker pick;
  final bool photoSupported;
  final Future<Directory> Function() docsDir;

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
      Profile(
        name: name ?? p.name,
        icon: icon ?? p.icon,
        bg: bg ?? p.bg,
        // choosing an icon goes back to the icon
        photo: icon == null ? p.photo : null,
      ),
    );
  }

  Future<void> _choose() async {
    try {
      final path = await widget.pick();
      if (path == null || path.isEmpty) return;
      // copy it, so it survives the picker's temp cleanup
      final dir = await widget.docsDir();
      final kept = await File(path).copy('${dir.path}/profile.jpg');
      await FileImage(kept).evict();
      final p = appState.profile;
      appState.setProfile(
        Profile(name: p.name, icon: p.icon, bg: p.bg, photo: kept.path),
      );
    } catch (e) {
      appLog.w('profile', 'photo pick failed ${e.runtimeType}');
    }
  }

  Future<void> _remove() async {
    final p = appState.profile;
    final path = p.photo;
    appState.setProfile(Profile(name: p.name, icon: p.icon, bg: p.bg));
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (e) {
      appLog.w('profile', 'photo delete failed ${e.runtimeType}');
    }
  }

  Widget _ring(Widget child, bool on, ColorScheme c) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? c.secondaryContainer : null,
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
                          'your name and photo',
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
                        decoration: const InputDecoration(counterText: ''),
                      ),
                      if (widget.photoSupported) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                key: const ValueKey('profile-photo-choose'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                ),
                                onPressed: _choose,
                                child: const Text('choose a photo'),
                              ),
                            ),
                            if (p.photo != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonal(
                                  key: const ValueKey('profile-photo-remove'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                  ),
                                  onPressed: _remove,
                                  child: const Text('remove photo'),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Caption('your photo stays on this phone'),
                      ],
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
                                p.photo == null && p.icon == i,
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
