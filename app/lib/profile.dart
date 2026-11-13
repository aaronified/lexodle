/// The player's own name and avatar, shown on the you page.
///
/// The avatar is an icon on a coloured circle, or a photo from the gallery.
/// The photo stays on this phone: only its path is stored, and it is not part
/// of backups.
const profileIcons = [
  'ghost',
  'puzzle',
  'bulb',
  'flame',
  'bolt',
  'chess-knight',
  'world',
  'trophy',
];

/// The longest name, in characters.
const profileNameMax = 16;

/// The number of avatar background colours (taken from the colour scheme).
const profileColours = 4;

class Profile {
  Profile({
    this.name = 'player',
    this.icon = 'ghost',
    this.bg = 0,
    this.photo,
  }) {
    name = _name(name);
    icon = profileIcons.contains(icon) ? icon : profileIcons.first;
    bg = _bg(bg);
  }

  String name;
  String icon;
  int bg;

  /// The path of the chosen photo, or null when the icon is shown.
  String? photo;

  static String _name(String n) => n.runes.length > profileNameMax
      ? String.fromCharCodes(n.runes.take(profileNameMax))
      : n;

  static int _bg(int b) => b >= 0 && b < profileColours ? b : 0;

  Map<String, dynamic> toJson() => {
    'name': name,
    'icon': icon,
    'bg': bg,
    if (photo != null) 'photo': photo,
  };

  /// Reads a profile; anything missing or damaged falls back to the default.
  factory Profile.fromJson(Object? j) {
    if (j is! Map) return Profile();
    final n = j['name'];
    final i = j['icon'];
    final b = j['bg'];
    final ph = j['photo'];
    return Profile(
      name: n is String ? n : 'player',
      icon: i is String ? i : 'ghost',
      bg: b is int ? b : 0,
      photo: ph is String && ph.isNotEmpty ? ph : null,
    );
  }
}
