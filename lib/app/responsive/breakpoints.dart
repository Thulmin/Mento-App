// Defines the shared screen-size rules used by Mento's responsive layouts.

import 'package:flutter/material.dart';

enum MentoWindowClass { compact, medium, expanded }

/// Chooses a compact, medium, or expanded layout from the available width.
abstract final class MentoBreakpoints {
  static const compact = 600.0;
  static const expanded = 840.0;

  static MentoWindowClass ofWidth(double width) {
    if (width < compact) return MentoWindowClass.compact;
    if (width < expanded) return MentoWindowClass.medium;
    return MentoWindowClass.expanded;
  }
}

extension MentoResponsiveContext on BuildContext {
  MentoWindowClass get windowClass =>
      MentoBreakpoints.ofWidth(MediaQuery.sizeOf(this).width);

  bool get isCompact => windowClass == MentoWindowClass.compact;

  EdgeInsets get pagePadding => switch (windowClass) {
    MentoWindowClass.compact => const EdgeInsets.fromLTRB(16, 8, 16, 24),
    MentoWindowClass.medium => const EdgeInsets.fromLTRB(24, 16, 24, 32),
    MentoWindowClass.expanded => const EdgeInsets.fromLTRB(32, 20, 32, 40),
  };

  double get contentMaxWidth => switch (windowClass) {
    MentoWindowClass.compact => double.infinity,
    MentoWindowClass.medium => 920,
    MentoWindowClass.expanded => 1240,
  };
}

class MentoPage extends StatelessWidget {
  const MentoPage({
    required this.child,
    this.scrollable = true,
    this.padding,
    super.key,
  });

  final Widget child;
  final bool scrollable;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: Padding(padding: padding ?? context.pagePadding, child: child),
      ),
    );
    if (!scrollable) return content;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: content,
    );
  }
}

class MentoResponsiveGrid extends StatelessWidget {
  const MentoResponsiveGrid({
    required this.children,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 3,
    this.spacing = 16,
    super.key,
  });

  final List<Widget> children;
  final int compactColumns;
  final int mediumColumns;
  final int expandedColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowClass = MentoBreakpoints.ofWidth(constraints.maxWidth);
        final columns = switch (windowClass) {
          MentoWindowClass.compact => compactColumns,
          MentoWindowClass.medium => mediumColumns,
          MentoWindowClass.expanded => expandedColumns,
        };
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
