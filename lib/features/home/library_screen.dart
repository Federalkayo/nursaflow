import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/utils/responsive.dart';
import 'models/document.dart';
import 'widgets/document_status_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _selectedCourse = 'All';

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(userDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: Responsive.isMobile(context) ? 80.0 : 0.0,
        ),
        child: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => context.push('/upload'),
          icon: const Icon(Symbols.add),
          label: const Text('Upload'),
        ),
      ),
      body: SafeArea(
        child: ResponsivePage(
          child: documentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading documents: $err')),
            data: (documents) {
              final courses = ['All', ...{for (final d in documents) d.course}];
              final filtered = _selectedCourse == 'All'
                  ? documents
                  : documents.where((d) => d.course == _selectedCourse).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: courses.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (context, i) => ChoiceChip(
                        label: Text(courses[i]),
                        selected: _selectedCourse == courses[i],
                        onSelected: (_) => setState(() => _selectedCourse = courses[i]),
                        labelStyle: AppTextStyles.bodySm(
                          color: _selectedCourse == courses[i]
                              ? AppColors.onPrimary
                              : AppColors.primary,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: filtered.isEmpty
                        ? _EmptyState(onUpload: () => context.push('/upload'))
                        : GridView.builder(
                            padding: EdgeInsets.only(
                              bottom: Responsive.isMobile(context) ? 96.0 : AppSpacing.md,
                            ),
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisSpacing: AppSpacing.sm,
                              crossAxisSpacing: AppSpacing.sm,
                              childAspectRatio: Responsive.isMobile(context) ? 0.78 : 0.95,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) =>
                                DocumentStatusCard(document: filtered[i]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.folder_open, size: 56, color: AppColors.outlineVariant),
          const SizedBox(height: AppSpacing.sm),
          Text('No documents in this course yet', style: AppTextStyles.bodyMd()),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(label: 'Upload Notes', expand: false, onPressed: onUpload),
        ],
      ),
    );
  }
}
