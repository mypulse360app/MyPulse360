import 'package:flutter/material.dart';

import '../../../config/theme/app_radii.dart';
import '../../../config/theme/app_theme.dart';

/// Text field with inline validation states and password visibility toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.isPassword,
    this.keyboardType,
    this.errorText,
    this.isValid = false,
    this.onChanged,
    this.suffixIcon,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final bool? isPassword;
  final TextInputType? keyboardType;
  final String? errorText;
  final bool isValid;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure;

  bool get _isPasswordField => widget.isPassword ?? widget.obscureText;

  @override
  void initState() {
    super.initState();
    _obscure = _isPasswordField;
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.isPassword ?? oldWidget.obscureText) != _isPasswordField) {
      _obscure = _isPasswordField;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderColor = widget.errorText != null
        ? colors.danger
        : widget.isValid
            ? colors.success
            : colors.border;

    Widget? suffix;
    if (_isPasswordField) {
      final eyeButton = IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: colors.textSecondary,
          size: 20,
        ),
        tooltip: _obscure ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscure = !_obscure),
      );

      if (widget.isValid && widget.errorText == null) {
        suffix = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: colors.success, size: 20),
            eyeButton,
          ],
        );
      } else {
        suffix = eyeButton;
      }
    } else {
      suffix = widget.isValid && widget.errorText == null
          ? Icon(Icons.check_circle, color: colors.success, size: 20)
          : widget.suffixIcon;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: _isPasswordField ? _obscure : widget.obscureText,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          autofillHints: widget.autofillHints,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: BorderSide(color: widget.errorText != null ? colors.danger : colors.patientAccent, width: 1.5),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(widget.errorText!, style: TextStyle(color: colors.danger, fontSize: 12)),
        ],
      ],
    );
  }
}

