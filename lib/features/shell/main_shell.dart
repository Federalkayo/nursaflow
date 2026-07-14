import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/responsive.dart';

class NavDestinationData {
  const NavDestinationData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _destinations = [
  NavDestinationData(icon: Symbols.home, selectedIcon: Symbols.home, label: 'Home'),
  NavDestinationData(
      icon: Symbols.library_books,
      selectedIcon: Symbols.library_books,
      label: 'Library'),
  NavDestinationData(
      icon: Symbols.psychology, selectedIcon: Symbols.psychology, label: 'Study'),
  NavDestinationData(
      icon: Symbols.calendar_month,
      selectedIcon: Symbols.calendar_month,
      label: 'Planner'),
  NavDestinationData(icon: Symbols.person, selectedIcon: Symbols.person, label: 'Profile'),
];

/// Adaptive shell: bottom tab bar (frosted glass, per DESIGN.md) on mobile,
/// a side NavigationRail on tablet/desktop where horizontal space allows it.
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = Responsive.isTablet(context) || Responsive.isDesktop(context);

    if (isDesktopOrTablet) {
      return Scaffold(
        body: Row(
          children: [
            _SideRail(
              selectedIndex: navigationShell.currentIndex,
              onSelect: _onTap,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _BottomBar(
        selectedIndex: navigationShell.currentIndex,
        onSelect: _onTap,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 8,
            bottom: MediaQuery.paddingOf(context).bottom + 8,
            left: 8,
            right: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.85),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowTint.withValues(alpha: 0.05),
                offset: const Offset(0, -4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < _destinations.length; i++)
                _NavItem(
                  data: _destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.data, required this.selected, required this.onTap});

  final NavDestinationData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedScale(
          scale: selected ? 1.0 : 0.96,
          duration: const Duration(milliseconds: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? data.selectedIcon : data.icon,
                  color: color,
                  fill: selected ? 1 : 0,
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(data.label, style: AppTextStyles.labelSm(color: color)),
                if (selected) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      backgroundColor: AppColors.surface,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Icon(Symbols.health_and_safety, color: AppColors.primary, size: 32),
      ),
      selectedIconTheme: const IconThemeData(color: AppColors.primary, fill: 1),
      unselectedIconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
      selectedLabelTextStyle: AppTextStyles.labelSm(color: AppColors.primary),
      unselectedLabelTextStyle: AppTextStyles.labelSm(color: AppColors.onSurfaceVariant),
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
      ],
    );
  }
}
