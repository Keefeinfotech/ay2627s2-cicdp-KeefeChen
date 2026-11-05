import 'package:flutter/material.dart';

import '../../../core/models/avatar_style.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../data/avatar_store.dart';

/// Opens the avatar editor. Returns true when a new style was saved.
Future<bool> showAvatarEditorDialog(
  BuildContext context,
  AvatarStore store, {
  String? name,
  String? email,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => AvatarEditorDialog(store: store, name: name, email: email),
  );
  return saved ?? false;
}

/// Colour and glyph picker with a live preview.
class AvatarEditorDialog extends StatefulWidget {
  const AvatarEditorDialog({
    super.key,
    required this.store,
    this.name,
    this.email,
  });

  final AvatarStore store;
  final String? name;
  final String? email;

  @override
  State<AvatarEditorDialog> createState() => _AvatarEditorDialogState();
}

class _AvatarEditorDialogState extends State<AvatarEditorDialog> {
  late AvatarStyle _draft = widget.store.style;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.store.save(_draft);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.face_retouching_natural_outlined, size: 28),
      title: const Text('Customize avatar'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: AppAvatar(
                  name: widget.name,
                  email: widget.email,
                  size: 72,
                  style: _draft,
                  tooltip: 'Avatar preview',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'COLOUR',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final accent in AvatarAccent.values)
                    _AccentSwatch(
                      accent: accent,
                      selected: _draft.accent == accent,
                      onTap: () => setState(
                        () => _draft = _draft.copyWith(accent: accent),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'LOOK',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('Initials'),
                    selected: !_draft.usesGlyph,
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _draft = _draft.copyWith(glyph: null)),
                  ),
                  for (final glyph in AvatarStyle.glyphChoices)
                    ChoiceChip(
                      label: Text(glyph, style: const TextStyle(fontSize: 18)),
                      selected: _draft.glyph == glyph,
                      showCheckmark: false,
                      tooltip: 'Use $glyph',
                      onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(glyph: glyph),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Save avatar',
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AvatarAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: accent.label,
      child: Tooltip(
        message: accent.label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.onSurface : Colors.transparent,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        ),
      ),
    );
  }
}
