import 'package:flutter/material.dart';

import '../design_system/ds_tokens.dart';

/// Curated accent colours for the profile avatar.
///
/// The palette is deliberately small and drawn from the design system so a
/// customised avatar still looks at home next to primary buttons and status
/// badges. The `violet` identifier is retained only for persisted preferences;
/// it now renders as a deep Trust Blue accent, not purple.
enum AvatarAccent { trustBlue, emerald, amber, rose, violet, slate }

extension AvatarAccentStyle on AvatarAccent {
  String get label => switch (this) {
    AvatarAccent.trustBlue => 'Trust blue',
    AvatarAccent.emerald => 'Emerald',
    AvatarAccent.amber => 'Amber',
    AvatarAccent.rose => 'Rose',
    AvatarAccent.violet => 'Deep blue',
    AvatarAccent.slate => 'Slate',
  };

  Color get background => switch (this) {
    AvatarAccent.trustBlue => const Color(0xFF6B7C98),
    AvatarAccent.emerald => const Color(0xFF047857),
    AvatarAccent.amber => const Color(0xFFB45309),
    AvatarAccent.rose => const Color(0xFFBE123C),
    AvatarAccent.violet => Ds.trustBlueDark,
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
/// Avatars are rendered locally from an uploaded photo, initials, or a glyph
/// saved by an older version of the app. Photos are downscaled by the picker
/// and kept as a base64 data string in SharedPreferences: no upload bucket,
/// account sync or network connection is needed, so this works offline and on
/// the web build as well as on device.
class AvatarStyle {
  const AvatarStyle({
    this.accent = AvatarAccent.trustBlue,
    this.glyph,
    this.imageData,
  });

  static const Object _unset = Object();

  static const int maxGlyphLength = 4;

  /// Guard against corrupted or oversized preferences (~1.5 MB of image).
  static const int maxImageDataLength = 2000000;

  final AvatarAccent accent;

  /// An emoji saved by a previous app version. New choices do not use glyphs;
  /// this is kept so existing preferences keep rendering after an upgrade.
  final String? glyph;

  /// Base64-encoded JPEG bytes of the user's chosen photo.
  final String? imageData;

  bool get usesImage => imageData != null && imageData!.trim().isNotEmpty;

  bool get usesGlyph => !usesImage && glyph != null && glyph!.trim().isNotEmpty;

  AvatarStyle copyWith({
    AvatarAccent? accent,
    Object? glyph = _unset,
    Object? imageData = _unset,
  }) {
    return AvatarStyle(
      accent: accent ?? this.accent,
      glyph: identical(glyph, _unset) ? this.glyph : _normalizeGlyph(glyph),
      imageData: identical(imageData, _unset)
          ? this.imageData
          : _normalizeImageData(imageData),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accent': accent.name,
    'glyph': glyph,
    'imageData': imageData,
  };

  static AvatarStyle? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    return AvatarStyle(
      accent: AvatarAccentStyle.fromName(raw['accent'] as String?),
      glyph: _normalizeGlyph(raw['glyph']),
      imageData: _normalizeImageData(raw['imageData']),
    );
  }

  static String? _normalizeGlyph(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxGlyphLength) return null;
    return trimmed;
  }

  static String? _normalizeImageData(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxImageDataLength) return null;
    return trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarStyle &&
      other.accent == accent &&
      other.glyph == glyph &&
      other.imageData == imageData;

  @override
  int get hashCode => Object.hash(accent, glyph, imageData);
}
