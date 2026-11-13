/// The player's own name and avatar, shown on the you page.
///
/// The avatar is an icon on a coloured circle. A photo can be chosen instead
/// in a later version; the profile will then gain a field for it.
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
  Profile({this.name = 'player', this.icon = 'ghost', this.bg = 0}) {
    name = _name(name);
    icon = profileIcons.contains(icon) ? icon : profileIcons.first;
    bg = _bg(bg);
  }

  String name;
  String icon;
  int bg;

  static String _name(String n) => n.runes.length > profileNameMax
      ? String.fromCharCodes(n.runes.take(profileNameMax))
      : n;

  static int _bg(int b) => b >= 0 && b < profileColours ? b : 0;

  Map<String, dynamic> toJson() => {'name': name, 'icon': icon, 'bg': bg};

  /// Reads a profile; anything missing or damaged falls back to the default.
  factory Profile.fromJson(Object? j) {
    if (j is! Map) return Profile();
    final n = j['name'];
    final i = j['icon'];
    final b = j['bg'];
    return Profile(
      name: n is String ? n : 'player',
      icon: i is String ? i : 'ghost',
      bg: b is int ? b : 0,
    );
  }
}
