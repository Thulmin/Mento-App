// Presents consistent loading, empty, error, offline, and progress states.

import 'package:flutter/material.dart';

import '../../app/theme/mento_colors.dart';
import 'mento_controls.dart';

class MentoEmptyState extends StatelessWidget {
  const MentoEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$title. $message',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: context.mentoColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.mentoColors.textSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                MentoButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class MentoErrorState extends StatelessWidget {
  const MentoErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => MentoEmptyState(
    title: title,
    message: message,
    icon: Icons.error_outline,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}

class MentoLoadingSkeleton extends StatefulWidget {
  const MentoLoadingSkeleton({
    this.height = 96,
    this.width = double.infinity,
    this.borderRadius = 16,
    super.key,
  });

  final double height;
  final double width;
  final double borderRadius;

  @override
  State<MentoLoadingSkeleton> createState() => _MentoLoadingSkeletonState();
}

class _MentoLoadingSkeletonState extends State<MentoLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _controller,
        builder:
            (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  base,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  disableAnimations ? 0.2 : _controller.value,
                ),
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
              child: SizedBox(width: widget.width, height: widget.height),
            ),
      ),
    );
  }
}

class MentoOfflineBanner extends StatelessWidget {
  const MentoOfflineBanner({required this.visible, super.key});

  final bool visible;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration:
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
    child:
        visible
            ? Semantics(
              liveRegion: true,
              label:
                  'Offline. Showing saved data; some actions will sync later.',
              child: ColoredBox(
                color: context.mentoColors.warning,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 18,
                          color: context.mentoColors.onWarning,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Offline — saved data remains available',
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              color: context.mentoColors.onWarning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            : const SizedBox.shrink(),
  );
}

class MentoProgressRing extends StatelessWidget {
  const MentoProgressRing({
    required this.value,
    this.size = 80,
    this.strokeWidth = 8,
    this.label,
    super.key,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0);
    final percentage = (progress * 100).round();
    return Semantics(
      label: label ?? 'Progress',
      value: '$percentage percent',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
            ),
            Center(
              child: ExcludeSemantics(
                child: Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
