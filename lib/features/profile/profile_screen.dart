import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';
import '../home/models/document.dart';
import 'account_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon')),
    );
  }

  // Fully signs the user out — clears both the Firebase session and the
  // cached Google account, so the account picker shows again next time
  // instead of silently re-using whichever Google account was last used.
  Future<void> _logout(BuildContext context) async {
    final googleSignIn = GoogleSignIn();

    // Call both unconditionally — isSignedIn() can under-report the native
    // session state on some devices, causing disconnect() to be skipped.
    // signOut() clears the local cached account; disconnect() revokes the
    // granted access entirely, which is what actually forces the full
    // account chooser to reappear on the next sign-in attempt.
    try {
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint('GoogleSignIn signOut() error: $e');
    }

    try {
      await googleSignIn.disconnect();
    } catch (e) {
      debugPrint('GoogleSignIn disconnect() error: $e');
    }

    await FirebaseAuth.instance.signOut();

    if (context.mounted) {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docCount = ref.watch(userDocumentsProvider).valueOrNull?.length ?? 0;
    final user = ref.watch(currentUserProvider).valueOrNull ?? FirebaseAuth.instance.currentUser;
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
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          backgroundImage:
                              user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                          child: user?.photoURL == null
                              ? const Icon(Symbols.person, size: 44, color: AppColors.primary)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => context.push('/account'),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Symbols.edit, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(user?.displayName ?? 'User', style: AppTextStyles.headlineMd()),
                    if (user?.email != null)
                      Text(user!.email!, style: AppTextStyles.bodySm()),
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
              // Total Hours and Mastery Score removed — there's no study-time
              // tracking or quiz-mastery scoring built yet, and showing made
              // up numbers here would be worse than showing nothing.
              _StatCard(icon: Symbols.description, value: '$docCount', label: 'Docs Uploaded'),
              const SizedBox(height: AppSpacing.lg),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Symbols.person_outline,
                      title: 'Account',
                      subtitle: 'Personal info, school credentials',
                      onTap: () => context.push('/account'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Symbols.notifications_none,
                      title: 'Notifications',
                      subtitle: 'Study reminders, exam alerts',
                      onTap: () => context.push('/notifications'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Symbols.shield,
                      title: 'Data Privacy',
                      subtitle: 'Storage settings and security',
                      onTap: () => _comingSoon(context, 'Data & privacy settings'),
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
                      onTap: () => _logout(context),
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