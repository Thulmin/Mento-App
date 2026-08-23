// Contains accessible buttons, fields, chips, and badges styled for Mento.

import 'package:flutter/material.dart';

import '../../app/theme/mento_colors.dart';

enum MentoButtonVariant { filled, outlined, text, gradient }

class MentoScreenTitle extends StatelessWidget {
  const MentoScreenTitle({
    required this.title,
    required this.semanticIdentifier,
    super.key,
  });

  final String title;
  final String semanticIdentifier;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: semanticIdentifier,
    header: true,
    child: Text(title),
  );
}

class MentoButton extends StatelessWidget {
  const MentoButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconSize = 20,
    this.loading = false,
    this.expand = true,
    this.variant = MentoButtonVariant.filled,
    this.semanticIdentifier,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double iconSize;
  final bool loading;
  final bool expand;
  final MentoButtonVariant variant;
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    final callback = loading ? null : onPressed;
    final content =
        loading
            ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: iconSize),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            );

    Widget button = switch (variant) {
      MentoButtonVariant.filled => FilledButton(
        onPressed: callback,
        child: content,
      ),
      MentoButtonVariant.outlined => OutlinedButton(
        onPressed: callback,
        child: content,
      ),
      MentoButtonVariant.text => TextButton(
        onPressed: callback,
        child: content,
      ),
      MentoButtonVariant.gradient => DecoratedBox(
        decoration: BoxDecoration(
          gradient: callback == null ? null : MentoColors.primaryGradient,
          color:
              callback == null
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: FilledButton(
          onPressed: callback,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
          ),
          child: content,
        ),
      ),
    };
    if (expand) button = SizedBox(width: double.infinity, child: button);
    return Semantics(
      identifier: semanticIdentifier,
      button: true,
      label: label,
      liveRegion: loading,
      value: loading ? 'Loading' : null,
      onTap: callback,
      excludeSemantics: true,
      child: button,
    );
  }
}

class MentoIconButton extends StatelessWidget {
  const MentoIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.semanticIdentifier,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: semanticIdentifier,
    button: true,
    label: tooltip,
    onTap: onPressed,
    excludeSemantics: true,
    child: IconButton(onPressed: onPressed, tooltip: tooltip, icon: Icon(icon)),
  );
}

class MentoTextField extends StatelessWidget {
  const MentoTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofillHints,
    this.minLines,
    this.maxLines = 1,
    this.enabled = true,
    this.obscureText = false,
    this.semanticIdentifier,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final int? minLines;
  final int maxLines;
  final bool enabled;
  final bool obscureText;
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticIdentifier,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        autofillHints: autofillHints,
        minLines: minLines,
        maxLines: obscureText ? 1 : maxLines,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          errorText: errorText,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

class MentoPasswordField extends StatefulWidget {
  const MentoPasswordField({
    required this.label,
    this.controller,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.helper,
    this.semanticIdentifier,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? helper;
  final String? semanticIdentifier;

  @override
  State<MentoPasswordField> createState() => _MentoPasswordFieldState();
}

class _MentoPasswordFieldState extends State<MentoPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return MentoTextField(
      label: widget.label,
      semanticIdentifier: widget.semanticIdentifier,
      controller: widget.controller,
      validator: widget.validator,
      helper: widget.helper,
      obscureText: _obscured,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      autofillHints: const [AutofillHints.password],
      prefixIcon: Icons.lock_outline,
      suffixIcon: IconButton(
        tooltip: _obscured ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    );
  }
}

class MentoChip extends StatelessWidget {
  const MentoChip({
    required this.label,
    this.icon,
    this.selected = false,
    this.onSelected,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    avatar: icon == null ? null : Icon(icon, size: 18),
    selected: selected,
    onSelected: onSelected,
  );
}

class MentoBadge extends StatelessWidget {
  const MentoBadge({required this.label, this.icon, this.color, super.key});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: accent, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
