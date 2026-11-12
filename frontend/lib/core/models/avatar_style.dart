import 'package:flutter/material.dart';

/// Curated accent colours for the profile avatar.
///
/// The palette is deliberately small and drawn from the design system so a
/// customised avatar still looks at home next to primary buttons and status
/// badges.
enum AvatarAccent { trustBlue, emerald, amber, rose, violet, slate }

extension AvatarAccentStyle on AvatarAccent {
  String get label => switch (this) {
    AvatarAccent.trustBlue => 'Trust blue',
    AvatarAccent.emerald => 'Emerald',
    AvatarAccent.amber => 'Amber',
    AvatarAccent.rose => 'Rose',
    AvatarAccent.violet => 'Violet',
    AvatarAccent.slate => 'Slate',
  };

  Color get background => switch (this) {
    AvatarAccent.trustBlue => const Color(0xFF6B7C98),
    AvatarAccent.emerald => const Color(0xFF047857),
    AvatarAccent.amber => const Color(0xFFB45309),
    AvatarAccent.rose => const Color(0xFFBE123C),
    AvatarAccent.violet => const Color(0xFF6D28D9),
    AvatarAccent.slate => const Color(0xFF334155),
  };

  static AvatarAccent fromName(String? name) {
    for (final value in AvatarAccent.values) {
      if (value.name == name) return value;
    }
    return AvatarAccent.trustBlue;
  }
}

/// The persisted look of a user's avatar.
///
/// Avatars are rendered locally from initials or a curated glyph, so no image
/// upload, storage bucket or moderation flow is required.
class AvatarStyle {
  const AvatarStyle({this.accent = AvatarAccent.trustBlue, this.glyph});

  static const Object _unset = Object();

  /// Glyphs offered by the editor. Each is a single grapheme cluster.
  static const List<String> glyphChoices = <String>[
    '🎓',
    '📚',
    '🦉',
    '🚀',
    '🌱',
    '⚡',
    '🧠',
    '🎯',
  ];

  static const int maxGlyphLength = 4;

  final AvatarAccent accent;

  /// An emoji or short symbol replacing the initials. Null means initials.
  final String? glyph;

  bool get usesGlyph => glyph != null && glyph!.trim().isNotEmpty;

  AvatarStyle copyWith({AvatarAccent? accent, Object? glyph = _unset}) {
    return AvatarStyle(
      accent: accent ?? this.accent,
      glyph: identical(glyph, _unset) ? this.glyph : _normalizeGlyph(glyph),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accent': accent.name,
    'glyph': glyph,
  };

  static AvatarStyle? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    return AvatarStyle(
      accent: AvatarAccentStyle.fromName(raw['accent'] as String?),
      glyph: _normalizeGlyph(raw['glyph']),
    );
  }

  static String? _normalizeGlyph(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxGlyphLength) return null;
    return trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarStyle && other.accent == accent && other.glyph == glyph;

  @override
  int get hashCode => Object.hash(accent, glyph);
}
