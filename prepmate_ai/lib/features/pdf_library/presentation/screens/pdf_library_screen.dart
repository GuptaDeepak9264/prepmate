import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/entities/pdf_entity.dart';
import '../providers/pdf_provider.dart';

class PdfLibraryScreen extends ConsumerWidget {
  const PdfLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredPdfListProvider);
    final query = ref.watch(pdfSearchQueryProvider);
    final category = ref.watch(pdfCategoryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.pdfLibrary),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Upload PDF',
            onPressed: () => context.push(AppRoutes.pdfUpload),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppStrings.searchPDFs,
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => ref
                            .read(pdfSearchQueryProvider.notifier)
                            .state = '',
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (v) =>
                  ref.read(pdfSearchQueryProvider.notifier).state = v,
            ),
          ),

          // Category chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: AppConstants.pdfCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = AppConstants.pdfCategories[i];
                final isSelected = category == cat;
                return GestureDetector(
                  onTap: () => ref
                      .read(pdfCategoryFilterProvider.notifier)
                      .state = cat,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // PDF List
          Expanded(
            child: filteredAsync.when(
              data: (pdfs) => pdfs.isEmpty
                  ? EmptyState(
                      icon: Icons.picture_as_pdf_rounded,
                      title: AppStrings.noPDFs,
                      subtitle: AppStrings.noPDFsSubtitle,
                      actionLabel: 'Upload PDF',
                      onAction: () => context.push(AppRoutes.pdfUpload),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pdfs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) => _PdfTile(
                        pdf: pdfs[i],
                        index: i,
                      ),
                    ),
              loading: () => _buildShimmer(),
              error: (e, _) =>
                  AppErrorWidget(message: e.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.pdfUpload),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: Text(
          AppStrings.uploadPDF,
          style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const ShimmerBox(
        width: double.infinity,
        height: 90,
        borderRadius: AppRadius.lg,
      ),
    );
  }
}

// ─── PDF Tile ─────────────────────────────────────────────────────────────────

class _PdfTile extends ConsumerWidget {
  final PdfEntity pdf;
  final int index;

  const _PdfTile({required this.pdf, required this.index});

  Color get _categoryColor {
    switch (pdf.category) {
      case 'Mathematics':
        return AppColors.catMath;
      case 'Science':
        return AppColors.catScience;
      case 'History':
        return AppColors.catHistory;
      case 'Language':
        return AppColors.catLanguage;
      default:
        return AppColors.catGeneral;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => context.push(
        AppRoutes.pdfViewer,
        extra: {
          'pdfId': pdf.id,
          'pdfName': pdf.name,
          'pdfUrl': pdf.url,
          'lastPage': pdf.lastReadPage,
        },
      ),
      child: Row(
        children: [
          // PDF icon with category color
          Container(
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              color: _categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                  color: _categoryColor.withOpacity(0.2)),
            ),
            child: Icon(Icons.picture_as_pdf_rounded,
                color: _categoryColor, size: 24),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pdf.name,
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StatusBadge(
                        label: pdf.category, color: _categoryColor),
                    const SizedBox(width: 8),
                    Text(pdf.sizeLabel, style: AppTextStyles.bodySmall),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(pdf.uploadedAt),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
                if (pdf.pageCount > 0) ...[
                  const SizedBox(height: 8),
                  LinearPercentIndicator(
                    padding: EdgeInsets.zero,
                    lineHeight: 4,
                    percent: pdf.readProgress.clamp(0.0, 1.0),
                    progressColor: _categoryColor,
                    backgroundColor: _categoryColor.withOpacity(0.12),
                    barRadius: const Radius.circular(4),
                    trailing: Text(
                      'p.${pdf.lastReadPage}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textTertiary, size: 20),
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'open',
                  child: Row(children: [
                    Icon(Icons.open_in_new_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Open')
                  ])),
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete',
                        style: TextStyle(color: AppColors.error))
                  ])),
            ],
            onSelected: (v) async {
              if (v == 'open') {
                context.push(AppRoutes.pdfViewer, extra: {
                  'pdfId': pdf.id,
                  'pdfName': pdf.name,
                  'pdfUrl': pdf.url,
                  'lastPage': pdf.lastReadPage,
                });
              } else if (v == 'delete') {
                _confirmDelete(context, ref);
              }
            },
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 50)).fadeIn().slideX(
        begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete PDF'),
        content: Text('Remove "${pdf.name}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(pdfUploadProvider.notifier)
                  .deletePdf(pdf.id, pdf.url);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
