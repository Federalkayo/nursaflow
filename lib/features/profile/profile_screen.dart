import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ResponsivePage(
          child: ListView(
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        const CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          child: Icon(Symbols.person, size: 44, color: AppColors.primary),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Symbols.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Sarah Jenkins', style: AppTextStyles.headlineMd()),
                    Text('Senior Nursing Student • St. Jude Medical',
                        style: AppTextStyles.bodySm()),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Study Stats', style: AppTextStyles.headlineMd()),
                  const Icon(Symbols.monitoring, color: AppColors.outline),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const _StatCard(icon: Symbols.schedule, value: '124', label: 'Total Hours'),
              const SizedBox(height: AppSpacing.sm),
              const _StatCard(icon: Symbols.description, value: '48', label: 'Docs Uploaded'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Symbols.verified, color: AppColors.tertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('92%', style: AppTextStyles.display()),
                    Text('Mastery Score', style: AppTextStyles.bodySm()),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(value: 0.92, minHeight: 6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Symbols.person_outline,
                      title: 'Account',
                      subtitle: 'Personal info, school credentials',
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Symbols.notifications_none,
                      title: 'Notifications',
                      subtitle: 'Study reminders, exam alerts',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.tertiary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Active',
                            style: AppTextStyles.labelSm(color: AppColors.tertiary)),
                      ),
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Symbols.shield,
                      title: 'Data Privacy',
                      subtitle: 'Storage settings and security',
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Symbols.workspace_premium,
                      title: 'Subscription',
                      subtitle: 'Manage your NursaFlow plan',
                      onTap: () => context.push('/subscription'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Symbols.logout,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      titleColor: AppColors.error,
                      onTap: () => context.go('/auth'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text('NursaFlow Version 1.0.0', style: AppTextStyles.bodySm()),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(value, style: AppTextStyles.headlineMd()),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodyMd()),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: titleColor ?? AppColors.onSurfaceVariant),
      title: Text(title, style: AppTextStyles.labelLg(color: titleColor ?? AppColors.onSurface)),
      subtitle: Text(subtitle, style: AppTextStyles.bodySm()),
      trailing: trailing ?? const Icon(Symbols.chevron_right, color: AppColors.outline),
    );
  }
}
