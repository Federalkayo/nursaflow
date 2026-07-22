import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';
import 'models/privacy_actions.dart';

// TODO(kayode): point this at the real hosted Privacy Policy page once
// it's live, e.g. https://nursaflow.app/privacy
const String kPrivacyPolicyUrl = 'https://nursaflow.app/privacy';

class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  bool _exporting = false;
  bool _deleting = false;

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(kPrivacyPolicyUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Privacy Policy link.')),
      );
    }
  }

  Future<void> _exportData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _exporting = true);
    try {
      final json = await exportUserDataAsJson(uid);
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ExportPreviewSheet(json: json),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export your data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, uploaded documents, study '
          'planner, and notification history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _deleting = true);
    try {
      await deleteAccountAndAllData(uid);
      if (mounted) context.go('/onboarding');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'For your security, please log out and back in, then try deleting your account again.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete your account: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete your account: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data & Privacy')),
      body: SafeArea(
        child: ResponsivePage(
          child: ListView(
            children: [
              Text('What we collect', style: AppTextStyles.labelLg()),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Text(
                  'NursaFlow stores your account info (name, email, photo), '
                  'school credentials, uploaded documents and AI summaries, '
                  'and your study planner and activity — so your progress '
                  'stays in sync across devices. We never sell your data.',
                  style: AppTextStyles.bodyMd(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Symbols.policy, color: AppColors.onSurfaceVariant),
                      title: Text('Privacy Policy', style: AppTextStyles.labelLg()),
                      subtitle: Text('How we handle your data', style: AppTextStyles.bodySm()),
                      trailing: const Icon(Symbols.open_in_new, color: AppColors.outline, size: 18),
                      onTap: _openPrivacyPolicy,
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Symbols.download, color: AppColors.onSurfaceVariant),
                      title: Text('Export My Data', style: AppTextStyles.labelLg()),
                      subtitle: Text('Download a copy of everything we store', style: AppTextStyles.bodySm()),
                      trailing: _exporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Symbols.chevron_right, color: AppColors.outline),
                      onTap: _exporting ? null : _exportData,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('Danger Zone', style: AppTextStyles.labelLg(color: AppColors.error)),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(Symbols.delete_forever, color: AppColors.error),
                  title: Text('Delete My Account', style: AppTextStyles.labelLg(color: AppColors.error)),
                  subtitle: Text(
                    'Permanently erase your account and all your data',
                    style: AppTextStyles.bodySm(),
                  ),
                  trailing: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _deleting ? null : _confirmDeleteAccount,
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportPreviewSheet extends StatelessWidget {
  const _ExportPreviewSheet({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Your Data', style: AppTextStyles.headlineMd()),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(json, style: AppTextStyles.bodySm()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Copy to Clipboard',
              icon: Symbols.copy_all,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: json));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard.')),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}