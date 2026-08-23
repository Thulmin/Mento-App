// Contains the reusable card, statistic, and section-header building blocks.

import 'package:flutter/material.dart';

import '../../app/theme/mento_colors.dart';

class MentoCard extends StatelessWidget {
  const MentoCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.semanticLabel,
    this.highlighted = false,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      shape:
          highlighted
              ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
              )
              : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (semanticLabel == null) return card;
    return Semantics(label: semanticLabel, button: onTap != null, child: card);
  }
}

class MentoStatCard extends StatelessWidget {
  const MentoStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.supportingText,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? supportingText;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return MentoCard(
      semanticLabel:
          '$label: $value${supportingText == null ? '' : ', $supportingText'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: accent, semanticLabel: null),
            ),
          ),
          const SizedBox(height: 16),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          if (supportingText != null) ...[
            const SizedBox(height: 4),
            Text(
              supportingText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.mentoColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MentoSectionHeader extends StatelessWidget {
  const MentoSectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.mentoColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
