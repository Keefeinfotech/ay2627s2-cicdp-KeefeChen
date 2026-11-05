import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/models/avatar_style.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/profile/data/avatar_store.dart';
import 'package:frontend/features/profile/widgets/avatar_editor_dialog.dart';

Widget _host(AvatarStore store, ValueChanged<bool> onResult) {
  return MaterialApp(
    theme: AuxiliaTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final saved = await showAvatarEditorDialog(
              context,
              store,
              name: 'Sam Lee',
              email: 'sam@example.com',
            );
            onResult(saved);
          },
          child: const Text('Edit avatar'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, AvatarStore store) async {
  await tester.tap(find.text('Edit avatar'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('previews and saves a chosen colour and glyph', (tester) async {
    final store = AvatarStore(ownerId: 'owner');
    await store.load();
    bool? result;

    await tester.pumpWidget(_host(store, (value) => result = value));
    await _open(tester, store);

    expect(find.text('Customize avatar'), findsOneWidget);
    expect(find.text('COLOUR'), findsOneWidget);
    expect(find.text('LOOK'), findsOneWidget);
    expect(find.text('Save avatar'), findsOneWidget);

    await tester.tap(find.byTooltip('Violet'));
    await tester.pump();
    await tester.tap(find.text('🦉'));
    await tester.pump();
    await tester.tap(find.text('Save avatar'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(store.style.accent, AvatarAccent.violet);
    expect(store.style.glyph, '🦉');
    expect(find.text('Customize avatar'), findsNothing);
  });

  testWidgets('cancelling leaves the saved avatar unchanged', (tester) async {
    final store = AvatarStore(ownerId: 'owner');
    await store.load();
    await store.save(
      const AvatarStyle(accent: AvatarAccent.amber, glyph: '🎯'),
    );
    bool? result;

    await tester.pumpWidget(_host(store, (value) => result = value));
    await _open(tester, store);

    await tester.tap(find.byTooltip('Rose'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(store.style.accent, AvatarAccent.amber);
    expect(store.style.glyph, '🎯');
  });

  testWidgets('switching back to initials clears the glyph', (tester) async {
    final store = AvatarStore(ownerId: 'owner');
    await store.load();
    await store.save(
      const AvatarStyle(accent: AvatarAccent.emerald, glyph: '🚀'),
    );

    await tester.pumpWidget(_host(store, (_) {}));
    await _open(tester, store);

    await tester.tap(find.text('Initials'));
    await tester.pump();
    await tester.tap(find.text('Save avatar'));
    await tester.pumpAndSettle();

    expect(store.style.usesGlyph, isFalse);
    expect(store.style.accent, AvatarAccent.emerald);
  });
}
