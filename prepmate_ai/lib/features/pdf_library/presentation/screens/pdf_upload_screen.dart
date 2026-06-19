import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/pdf_provider.dart';

class PdfUploadScreen extends ConsumerStatefulWidget {
  const PdfUploadScreen({super.key});

  @override
  ConsumerState<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends ConsumerState<PdfUploadScreen> {
  File? _pickedFile;
  String _fileName = '';
  String _selectedCategory = 'General';
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final sizeBytes = await file.length();
      if (sizeBytes > AppConstants.maxFileSizeMB * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'File too large. Max ${AppConstants.maxFileSizeMB}MB.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      setState(() {
        _pickedFile = file;
        _fileName = path.basenameWithoutExtension(
            result.files.single.name);
        _nameCtrl.text = _fileName;
      });
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF first.')),
      );
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the PDF.')),
      );
      return;
    }

    final entity = await ref.read(pdfUploadProvider.notifier).uploadPdf(
          file: _pickedFile!,
          name: _nameCtrl.text.trim(),
          category: _selectedCategory,
        );

    if (!mounted) return;
    if (entity != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF uploaded successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } else {
      final err = ref.read(pdfUploadProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Upload failed. Try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(pdfUploadProvider);
    final isLoading = uploadState.isUploading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.uploadPDF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drop zone
            GestureDetector(
              onTap: isLoading ? null : _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: _pickedFile != null
                      ? AppColors.primary.withOpacity(0.05)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: _pickedFile != null
                        ? AppColors.primary
                        : AppColors.border,
                    width: _pickedFile != null ? 2 : 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _pickedFile != null
                    ? _FilePreview(file: _pickedFile!, fileName: _fileName)
                    : _DropZonePlaceholder(),
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.97, 0.97)),
            const SizedBox(height: 24),

            // PDF Name
            Text('PDF Name', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            AppTextField(
              controller: _nameCtrl,
              label: 'Enter PDF name',
              prefixIcon: Icons.title_rounded,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 20),

            // Category
            Text('Category', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.pdfCategories
                  .where((c) => c != 'All')
                  .map((cat) => _CategoryChip(
                        label: cat,
                        isSelected: _selectedCategory == cat,
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                      ))
                  .toList(),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 32),

            // Cloudinary upload progress
            if (isLoading) ...[
              _CloudinaryProgressBar(progress: uploadState.progress),
              const SizedBox(height: 16),
            ],

            // Upload button
            AppButton(
              label: 'Upload to Cloudinary',
              onPressed: isLoading ? null : _upload,
              isLoading: isLoading,
              icon: Icons.cloud_upload_rounded,
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

class _DropZonePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 12),
        Text('Tap to select a PDF', style: AppTextStyles.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Maximum ${AppConstants.maxFileSizeMB}MB',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

class _FilePreview extends StatelessWidget {
  final File file;
  final String fileName;

  const _FilePreview({required this.file, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: file.length(),
      builder: (context, snap) {
        final size = snap.data ?? 0;
        final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_rounded,
                color: AppColors.primary, size: 44),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                fileName,
                style: AppTextStyles.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Text('$sizeMb MB', style: AppTextStyles.bodySmall),
            const SizedBox(height: 8),
            const StatusBadge(
              label: '✓ Ready to upload',
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}


// ─── Cloudinary Upload Progress Widget ───────────────────────────────────────

class _CloudinaryProgressBar extends StatelessWidget {
  final double progress; // 0.0–1.0; 0 means indeterminate

  const _CloudinaryProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = progress.clamp(0.0, 1.0);
    final known = pct > 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Cloudinary logo colour dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3448C5), // Cloudinary brand blue
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Uploading to Cloudinary',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              known ? '${(pct * 100).toStringAsFixed(0)}%' : '—',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: known ? pct : null,
            minHeight: 7,
            backgroundColor: const Color(0xFF3448C5).withOpacity(0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3448C5)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          known
              ? 'Your PDF is being securely stored in Cloudinary'
              : 'Connecting to Cloudinary…',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
