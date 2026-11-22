import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/models/avatar_style.dart';
import 'package:frontend/core/widgets/app_avatar.dart';
import 'package:frontend/features/profile/data/avatar_store.dart';

// A valid 1x1 PNG, small enough to keep widget tests fast.
const String tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to trust blue initials', () async {
    final store = AvatarStore(ownerId: 'owner');
    await store.load();

    expect(store.style.accent, AvatarAccent.trustBlue);
    expect(store.style.usesGlyph, isFalse);
  });

  test('saves and reloads a custom accent and glyph per owner', () async {
    final store = AvatarStore(ownerId: 'owner');
    await store.save(
      const AvatarStyle(accent: AvatarAccent.violet, glyph: '🦉'),
    );

    final reloaded = AvatarStore(ownerId: 'owner');
    await reloaded.load();
    expect(reloaded.style.accent, AvatarAccent.violet);
    expect(reloaded.style.glyph, '🦉');

    final otherOwner = AvatarStore(ownerId: 'someone-else');
    await otherOwner.load();
    expect(otherOwner.style.accent, AvatarAccent.trustBlue);
    expect(otherOwner.style.glyph, isNull);
  });

  test('saves and reloads an uploaded photo', () async {
    final store = AvatarStore(ownerId: 'owner');
    await store.save(
      const AvatarStyle(accent: AvatarAccent.emerald, imageData: tinyPng),
    );

    final reloaded = AvatarStore(ownerId: 'owner');
    await reloaded.load();

    expect(reloaded.style.usesImage, isTrue);
    expect(reloaded.style.imageData, tinyPng);
    expect(reloaded.style.usesGlyph, isFalse);
  });

  test('oversized photo data is rejected', () {
    final style = const AvatarStyle().copyWith(
      imageData: 'x' * (AvatarStyle.maxImageDataLength + 1),
    );
    expect(style.imageData, isNull);
    expect(style.usesImage, isFalse);
  });

  test('a malformed preference falls back to the default avatar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auxilia.avatar.v1.owner': 'not-json',
    });
    final store = AvatarStore(ownerId: 'owner');

    await store.load();

    expect(store.style.accent, AvatarAccent.trustBlue);
    expect(store.style.usesGlyph, isFalse);
  });

  test('a future schema version is ignored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auxilia.avatar.v1.owner':
          '{"version":99,"style":{"accent":"rose","glyph":"🚀"}}',
    });
    final store = AvatarStore(ownerId: 'owner');

    await store.load();

    expect(store.style.accent, AvatarAccent.trustBlue);
  });

  test('glyphs longer than four characters are rejected', () {
    final style = const AvatarStyle().copyWith(glyph: 'toolong');
    expect(style.glyph, isNull);

    final trimmed = const AvatarStyle().copyWith(glyph: '  🎓  ');
    expect(trimmed.glyph, '🎓');
  });

  test('reset restores the default style', () async {
    final store = AvatarStore(ownerId: 'owner');
    await store.save(
      const AvatarStyle(accent: AvatarAccent.amber, glyph: '🎯'),
    );

    await store.reset();

    expect(store.style, const AvatarStyle());
  });

  testWidgets('AppAvatar renders a chosen glyph and accent colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAvatar(
            name: 'Sam Lee',
            style: AvatarStyle(accent: AvatarAccent.emerald, glyph: '🌱'),
          ),
        ),
      ),
    );

    expect(find.text('🌱'), findsOneWidget);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, AvatarAccent.emerald.background);
  });

  testWidgets('AppAvatar renders a saved photo instead of initials', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAvatar(
            name: 'Sam Lee',
            style: AvatarStyle(imageData: tinyPng),
          ),
        ),
      ),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<MemoryImage>());
    expect(find.text('SL'), findsNothing);
  });
}
