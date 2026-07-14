import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive.dart';

/// Wraps screen content so it:
/// - Uses a single column with 20px margins on mobile
/// - Gets 24px margins on tablet
/// - Centers to a max width of 1200px on desktop (per DESIGN.md grid spec)
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.padTop = true,
    this.padBottom = true,
  });

  final Widget child;
  final bool padTop;
  final bool padBottom;

  @override
  Widget build(BuildContext context) {
    final margin = Responsive.horizontalMargin(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.maxContentWidth,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: margin,
            right: margin,
            top: padTop ? AppSpacing.md : 0,
            bottom: padBottom ? AppSpacing.md : 0,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A two/three-column responsive grid for card layouts (e.g. document
/// library, planner day cards). Falls back to a single scrollable column
/// on mobile.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
    this.childAspectRatio = 1.0,
  });

  final List<Widget> children;
  final double spacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.gridColumns(context);
    if (columns == 1) {
      return Column(
        children: [
          for (final c in children) ...[
            c,
            if (c != children.last) SizedBox(height: spacing),
          ],
        ],
      );
    }
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
