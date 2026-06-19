import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final mcqAsync = ref.watch(mcqStatsProvider);
    final pdfAsync = ref.watch(pdfCountProvider);
    final streakAsync = ref.watch(streakProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => userAsync.whenData(
              (u) => u != null ? _showEditNameSheet(context, ref, u) : null,
            ),
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Avatar & Name ─────────────────────────────────────────
                _ProfileHeader(user: user).animate().fadeIn().slideY(
                    begin: -0.05, end: 0, duration: 400.ms),
                const SizedBox(height: 28),

                // ── Stats Grid ────────────────────────────────────────────
                SectionHeader(title: 'Your Stats')
                    .animate()
                    .fadeIn(delay: 100.ms),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: streakAsync.when(
                        data: (s) => _StatTile(
                          icon: '🔥',
                          label: 'Streak',
                          value: '${s.currentStreak}d',
                          color: const Color(0xFFFF6B6B),
                        ),
                        loading: () => const ShimmerBox(
                            width: double.infinity, height: 80),
                        error: (_, __) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: pdfAsync.when(
                        data: (c) => _StatTile(
                          icon: '📄',
                          label: 'PDFs',
                          value: c.toString(),
                          color: AppColors.catGeneral,
                        ),
                        loading: () => const ShimmerBox(
                            width: double.infinity, height: 80),
                        error: (_, __) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: mcqAsync.when(
                        data: (s) => _StatTile(
                          icon: '🎯',
                          label: 'Accuracy',
                          value:
                              '${(s['accuracy'] as double).toStringAsFixed(0)}%',
                          color: AppColors.accent,
                        ),
                        loading: () => const ShimmerBox(
                            width: double.infinity, height: 80),
                        error: (_, __) => const SizedBox(),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 28),

                // ── Account Section ───────────────────────────────────────
                SectionHeader(title: 'Account')
                    .animate()
                    .fadeIn(delay: 200.ms),
                const SizedBox(height: 12),
                _SettingsSection(
                  items: [
                    _SettingsItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Full Name',
                      subtitle: user.name,
                      onTap: () => _showEditNameSheet(context, ref, user),
                    ),
                    _SettingsItem(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      subtitle: user.email,
                    ),
                    _SettingsItem(
                      icon: Icons.calendar_month_outlined,
                      title: 'Member Since',
                      subtitle: DateFormat('MMMM yyyy')
                          .format(user.createdAt),
                    ),
                  ],
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 20),

                // ── App Section ───────────────────────────────────────────
                SectionHeader(title: 'App')
                    .animate()
                    .fadeIn(delay: 300.ms),
                const SizedBox(height: 12),
                _SettingsSection(
                  items: [
                    _SettingsItem(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Manage reminders',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.info_outline_rounded,
                      title: 'App Version',
                      subtitle: AppConstants.appVersion,
                    ),
                  ],
                ).animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 20),

                // ── Sign Out ──────────────────────────────────────────────
                AppCard(
                  onTap: () => _confirmSignOut(context, ref),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: AppColors.error, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.logout,
                        style: AppTextStyles.titleMedium
                            .copyWith(color: AppColors.error),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: AppColors.error),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppErrorWidget(message: e.toString()),
      ),
    );
  }

  void _showEditNameSheet(
      BuildContext context, WidgetRef ref, UserEntity user) {
    final ctrl = TextEditingController(text: user.name);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Name', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 16),
              AppTextField(
                controller: ctrl,
                label: AppStrings.nameLabel,
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),
              Consumer(builder: (_, ref, __) {
                final profileState = ref.watch(profileNotifierProvider);
                return AppButton(
                  label: 'Save Changes',
                  isLoading: profileState.isUpdating,
                  onPressed: () async {
                    await ref
                        .read(profileNotifierProvider.notifier)
                        .updateName(ctrl.text);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.logout),
        content: const Text(AppStrings.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(profileNotifierProvider.notifier)
                  .signOut();
            },
            child: const Text(
              AppStrings.logout,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  final UserEntity user;

  const _ProfileHeader({required this.user});

  Future<void> _pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (picked == null || picked.files.single.path == null) return;
    final file = File(picked.files.single.path!);
    await ref
        .read(profileNotifierProvider.notifier)
        .uploadAvatar(file, user.uid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);
    final isUploadingAvatar =
        profileState.isUpdating && profileState.avatarUploadProgress > 0;

    return Column(
      children: [
        GestureDetector(
          onTap: profileState.isUpdating
              ? null
              : () => _pickAndUploadAvatar(context, ref),
          child: Stack(
            children: [
              // Avatar — show local progress ring during upload
              isUploadingAvatar
                  ? SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AppAvatar(
                            imageUrl: user.photoUrl,
                            name: user.name,
                            size: 88,
                          ),
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: CircularProgressIndicator(
                              value: profileState.avatarUploadProgress,
                              strokeWidth: 3,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.15),
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : AppAvatar(
                      imageUrl: user.photoUrl,
                      name: user.name,
                      size: 88,
                    ),
              // Camera badge
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: profileState.isUpdating
                        ? AppColors.textTertiary
                        : AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    profileState.isUpdating
                        ? Icons.hourglass_top_rounded
                        : Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(user.name, style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        Text(user.email,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        StatusBadge(
          label: '🎓 Active Learner',
          color: AppColors.primary,
        ),
      ],
    );
  }
}

// ─── Stat Tile ────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.headlineSmall
                .copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

// ─── Settings Section ─────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final List<_SettingsItem> items;

  const _SettingsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              _SettingsRow(item: item),
              if (!isLast)
                const Divider(
                    height: 1, indent: 56, color: AppColors.divider),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
}

class _SettingsRow extends StatelessWidget {
  final _SettingsItem item;

  const _SettingsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(item.icon,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTextStyles.titleMedium),
                  if (item.subtitle != null)
                    Text(item.subtitle!,
                        style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (item.onTap != null)
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
