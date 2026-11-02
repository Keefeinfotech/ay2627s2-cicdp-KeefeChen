import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Standard text input with optional password visibility, icons and validation.
///
/// It deliberately returns a [TextFormField] so existing forms, validators and
/// widget tests keep working while sharing one visual implementation.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.counterText,
    this.prefixIcon,
    this.suffixIcon,
    this.autofillHints,
    this.focusNode,
    this.contentPadding,
    this.showObscureToggle = false,
    this.useFormField = true,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final String? counterText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;
  final bool showObscureToggle;

  /// When false the widget renders a plain [TextField] instead of a
  /// [TextFormField]. Search bars and chat composers are not part of a form and
  /// should not appear in form-field lookups.
  final bool useFormField;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool canToggle = widget.showObscureToggle || widget.obscureText;

    Widget? suffix = widget.suffixIcon;
    if (canToggle) {
      final toggle = IconButton(
        tooltip: _obscured ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: AppSizes.iconMd,
        ),
      );
      suffix = suffix == null
          ? toggle
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[suffix, toggle],
            );
    }

    final TextStyle? style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface);
    final InputDecoration decoration = InputDecoration(
      labelText: widget.labelText,
      hintText: widget.hintText,
      helperText: widget.helperText,
      errorText: widget.errorText,
      counterText: widget.counterText,
      contentPadding: widget.contentPadding,
      prefixIcon: widget.prefixIcon == null
          ? null
          : Icon(widget.prefixIcon, size: AppSizes.iconMd),
      suffixIcon: suffix,
    );

    if (!widget.useFormField) {
      return TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        onSubmitted: widget.onFieldSubmitted,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        obscureText: _obscured,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        autofillHints: widget.autofillHints,
        style: style,
        decoration: decoration,
      );
    }

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      focusNode: widget.focusNode,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      obscureText: _obscured,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      autofillHints: widget.autofillHints,
      style: style,
      decoration: decoration,
    );
  }
}
