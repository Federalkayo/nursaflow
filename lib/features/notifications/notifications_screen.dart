import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/skeleton.dart';
import 'models/app_notification.dart';

IconData _iconFor(NotificationType type) {
  switch (type) {
    case NotificationType.documentReady:
      return Symbols.description;
    case NotificationType.tutorReply:
      return Symbols.smart_toy;
    case NotificationType.streak:
      return Symbols.local_fire_department;
    case NotificationType.subscription:
      return Symbols.workspace_premium;
    case NotificationType.announcement:
      return Symbols.campaign;
    case NotificationType.generic:
      return Symbols.notifications;
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _handleTap(BuildContext context, WidgetRef ref, String uid, AppNotification n) {
    if (!n.read) markNotificationRead(uid, n.id);

    switch (n.type) {
      case NotificationType.documentReady:
        if (n.refId != null) context.push('/document/${n.refId}/summary');
        break;
      case NotificationType.tutorReply:
        context.push('/tutor${n.refId != null ? '?documentId=${n.refId}' : ''}');
        break;
      case NotificationType.subscription:
        context.push('/subscription');
        break;
      case NotificationType.streak:
      case NotificationType.announcement:
      case NotificationType.generic:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: AppTextStyles.headlineMd()),
        actions: [
          notificationsAsync.maybeWhen(
            data: (list) => list.any((n) => !n.read)
                ? TextButton(
                    onPressed: uid == null ? null : () => markAllNotificationsRead(uid, list),
                    child: const Text('Mark all read'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsivePage(
          child: notificationsAsync.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return _EmptyState();
              }
              return ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final n = notifications[i];
                  return AppCard(
                    onTap: uid == null ? null : () => _handleTap(context, ref, uid, n),
                    color: n.read
                        ? AppColors.surfaceContainerLowest
                        : AppColors.surfaceContainerLow,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(_iconFor(n.type), size: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title, style: AppTextStyles.labelLg()),
                              const SizedBox(height: 2),
                              Text(n.body, style: AppTextStyles.bodySm()),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM d, h:mm a').format(n.createdAt),
                                style: AppTextStyles.bodySm(color: AppColors.outline),
                              ),
                            ],
                          ),
                        ),
                        if (!n.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4, left: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const SkeletonList(itemCount: 4),
            error: (_, __) => _EmptyState(),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl * 2),
        child: Column(
          children: [
            const Icon(Symbols.notifications_off, size: 40, color: AppColors.outline),
            const SizedBox(height: AppSpacing.sm),
            Text("You're all caught up", style: AppTextStyles.labelLg()),
            const SizedBox(height: 4),
            Text(
              "New alerts about your documents, tutor, and study streak show up here.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }
}
