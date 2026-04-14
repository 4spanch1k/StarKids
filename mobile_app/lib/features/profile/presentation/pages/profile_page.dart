import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_input_field.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../notifications/domain/notification_permission_status.dart';
import '../../../notifications/presentation/controllers/mobile_notifications_controller.dart';
import '../../../request_history/domain/request_history_item.dart';
import '../../domain/user_profile.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_section_card.dart';
import '../widgets/profile_shimmer.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.controller,
    this.notificationsController,
    this.selectedBranchOverride,
    this.onOpenBranchSelection,
    this.onOpenAllRequests,
    this.onLogout,
    this.appVersionOverride,
  });

  final ProfileController? controller;
  final MobileNotificationsController? notificationsController;
  final BranchOption? selectedBranchOverride;
  final VoidCallback? onOpenBranchSelection;
  final VoidCallback? onOpenAllRequests;
  final Future<void> Function()? onLogout;
  final String? appVersionOverride;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileController _controller;
  late final MobileNotificationsController _notificationsController;

  final _firstNameTextController = TextEditingController();
  final _lastNameTextController = TextEditingController();
  final _emailTextController = TextEditingController();

  bool _didInitTextControllers = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ServiceRegistry.profileController;
    _notificationsController =
        widget.notificationsController ?? ServiceRegistry.mobileNotificationsController;

    unawaited(_controller.load());
    unawaited(_notificationsController.bootstrap());

    _controller.addListener(_syncTextControllers);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTextControllers);
    _firstNameTextController.dispose();
    _lastNameTextController.dispose();
    _emailTextController.dispose();
    super.dispose();
  }

  void _syncTextControllers() {
    if (_controller.status == ProfileViewStatus.success && !_didInitTextControllers) {
      _didInitTextControllers = true;
      _firstNameTextController.text = _controller.firstNameDraft;
      _lastNameTextController.text = _controller.lastNameDraft;
      _emailTextController.text = _controller.emailDraft;
    }
  }

  BranchOption get _selectedBranch =>
      widget.selectedBranchOverride ??
      ServiceRegistry.selectedBranchController.selectedBranch;

  Future<void> _handleLogout() async {
    if (widget.onLogout != null) {
      await widget.onLogout!();
    } else {
      await ServiceRegistry.mobileAuthController.logout();
    }
  }

  void _handleOpenBranchSelection() {
    if (widget.onOpenBranchSelection != null) {
      widget.onOpenBranchSelection!();
    } else {
      Navigator.of(context).pushNamed(AppRoutes.branchSelection);
    }
  }

  void _handleOpenAllRequests() {
    if (widget.onOpenAllRequests != null) {
      widget.onOpenAllRequests!();
    } else {
      Navigator.of(context).pushNamed(AppRoutes.myRequests);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final cropper = ImageCropper();
    final cropped = await cropper.cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Обрезать фото',
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Обрезать фото',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return;

    final bytes = await cropped.readAsBytes();
    final fileName = cropped.path.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final contentType = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'png'
            ? 'image/png'
            : 'image/jpeg';

    await _controller.uploadAvatar(bytes, fileName, contentType);
  }

  Future<void> _handleDeleteAvatar() async {
    await _controller.deleteAvatar();
  }

  Future<void> _handleSave() async {
    await _controller.saveChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarKidsColors.surfaceCanvas,
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: StarKidsColors.surfaceCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, _notificationsController]),
        builder: (context, _) {
          return switch (_controller.status) {
            ProfileViewStatus.loading => const ProfileLoadingSkeleton(),
            ProfileViewStatus.error => _buildErrorState(context),
            ProfileViewStatus.empty || ProfileViewStatus.success => _buildContent(context),
          };
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(StarKidsSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: StarKidsColors.statusError,
              size: 48,
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            Text(
              'Не удалось загрузить профиль',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: StarKidsSpacing.sm),
            Text(
              _controller.errorMessage ?? 'Попробуйте снова.',
              style: textTheme.bodyMedium?.copyWith(
                color: StarKidsColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: StarKidsSpacing.xl),
            StarKidsButton.primary(
              label: 'Повторить',
              onPressed: _controller.retry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final profile = _controller.profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeaderCard(
            profile: profile,
            isUploadingAvatar: _controller.isUploadingAvatar,
            onPickAvatar: _pickAndUploadAvatar,
            onDeleteAvatar:
                (profile?.hasAvatar ?? false) ? _handleDeleteAvatar : null,
          ),
          if (_controller.errorMessage != null) ...[
            const SizedBox(height: StarKidsSpacing.lg),
            _InlineErrorBanner(
              message: _controller.errorMessage!,
              onDismiss: _controller.clearError,
            ),
          ],
          const SizedBox(height: StarKidsSpacing.xl),
          StarKidsContentSwitcher(
            child: _buildPersonalDataSection(context),
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          _buildBranchSection(context),
          const SizedBox(height: StarKidsSpacing.xl),
          _buildRequestsSection(context),
          const SizedBox(height: StarKidsSpacing.xl),
          _buildSettingsSection(context),
          const SizedBox(height: StarKidsSpacing.x2l),
          _buildFooter(context),
          const SizedBox(height: StarKidsSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildPersonalDataSection(BuildContext context) {
    return ProfileSectionCard(
      title: 'Личные данные',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StarKidsInputField(
            controller: _firstNameTextController,
            label: 'Имя',
            errorText: _controller.firstNameError,
            onChanged: _controller.updateFirstName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          StarKidsInputField(
            controller: _lastNameTextController,
            label: 'Фамилия',
            errorText: _controller.lastNameError,
            onChanged: _controller.updateLastName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          StarKidsInputField(
            controller: _emailTextController,
            label: 'Email',
            errorText: _controller.emailError,
            onChanged: _controller.updateEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          _ChildBirthDateField(
            selectedDate: _controller.childBirthDateDraft,
            errorText: _controller.childBirthDateError,
            onChanged: _controller.updateChildBirthDate,
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          StarKidsButton.primary(
            label: 'Сохранить',
            isLoading: _controller.isSaving,
            onPressed: _controller.canSave ? _handleSave : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSection(BuildContext context) {
    final branch = _selectedBranch;
    final textTheme = Theme.of(context).textTheme;

    return ProfileSectionCard(
      title: 'Мой филиал',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.name,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (branch.address.isNotEmpty) ...[
            const SizedBox(height: StarKidsSpacing.xs),
            Text(
              branch.address,
              style: textTheme.bodyMedium?.copyWith(
                color: StarKidsColors.textSecondary,
              ),
            ),
          ],
          if (branch.workingHours.isNotEmpty) ...[
            const SizedBox(height: StarKidsSpacing.xs),
            Text(
              branch.workingHours,
              style: textTheme.bodySmall?.copyWith(
                color: StarKidsColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: StarKidsSpacing.xl),
          StarKidsButton.secondary(
            label: 'Изменить филиал',
            onPressed: _handleOpenBranchSelection,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget content;

    switch (_controller.requestsStatus) {
      case ProfileRequestsStatus.loading:
        content = const Center(
          child: Padding(
            padding: EdgeInsets.all(StarKidsSpacing.lg),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case ProfileRequestsStatus.error:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _controller.requestsErrorMessage ?? 'Ошибка загрузки заявок.',
              style: textTheme.bodyMedium?.copyWith(
                color: StarKidsColors.statusError,
              ),
            ),
            const SizedBox(height: StarKidsSpacing.md),
            StarKidsButton.secondary(
              label: 'Повторить',
              onPressed: _controller.loadRequestPreview,
            ),
          ],
        );
      case ProfileRequestsStatus.empty:
        content = Text(
          'Заявок ещё нет.',
          style: textTheme.bodyMedium?.copyWith(
            color: StarKidsColors.textSecondary,
          ),
        );
      case ProfileRequestsStatus.success:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in _controller.previewRequests) ...[
              _RequestPreviewItem(item: item),
              const SizedBox(height: StarKidsSpacing.sm),
            ],
            if (_controller.totalRequests > 3)
              Padding(
                padding: const EdgeInsets.only(top: StarKidsSpacing.xs),
                child: Text(
                  'Ещё ${_controller.totalRequests - 3} заявок',
                  style: textTheme.bodySmall?.copyWith(
                    color: StarKidsColors.textSecondary,
                  ),
                ),
              ),
          ],
        );
    }

    return ProfileSectionCard(
      title: 'Мои заявки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          const SizedBox(height: StarKidsSpacing.xl),
          StarKidsButton.secondary(
            label: 'Все заявки',
            onPressed: _handleOpenAllRequests,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return ProfileSectionCard(
      title: 'Настройки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotificationToggleRow(
            notificationsController: _notificationsController,
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          const _LanguagePlaceholderRow(),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final version = widget.appVersionOverride ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StarKidsButton.secondary(
          label: 'Выйти',
          onPressed: _handleLogout,
        ),
        if (version.isNotEmpty) ...[
          const SizedBox(height: StarKidsSpacing.sm),
          Text(
            'Версия $version',
            style: textTheme.bodySmall?.copyWith(
              color: StarKidsColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ─── Header card ─────────────────────────────────────────────────────────────

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
    required this.isUploadingAvatar,
    required this.onPickAvatar,
    required this.onDeleteAvatar,
  });

  final UserProfile? profile;
  final bool isUploadingAvatar;
  final Future<void> Function() onPickAvatar;
  final Future<void> Function()? onDeleteAvatar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = profile;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(color: StarKidsColors.borderDefault),
        boxShadow: StarKidsShadows.depth1,
      ),
      child: Row(
        children: [
          _AvatarSection(
            profile: p,
            isUploading: isUploadingAvatar,
            onPickAvatar: onPickAvatar,
            onDeleteAvatar: onDeleteAvatar,
          ),
          const SizedBox(width: StarKidsSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p?.fullName ?? 'Профиль Star Kids',
                  style: textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p?.phone != null && p!.phone!.isNotEmpty) ...[
                  const SizedBox(height: StarKidsSpacing.xs),
                  Text(
                    p.phone!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: StarKidsColors.textSecondary,
                    ),
                  ),
                ] else if (p?.email != null && p!.email!.isNotEmpty) ...[
                  const SizedBox(height: StarKidsSpacing.xs),
                  Text(
                    p.email!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: StarKidsColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.profile,
    required this.isUploading,
    required this.onPickAvatar,
    required this.onDeleteAvatar,
  });

  final UserProfile? profile;
  final bool isUploading;
  final Future<void> Function() onPickAvatar;
  final Future<void> Function()? onDeleteAvatar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onPickAvatar,
      child: Stack(
        children: [
          _AvatarCircle(profile: profile, isUploading: isUploading),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: StarKidsColors.brandPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.profile, required this.isUploading});

  final UserProfile? profile;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    const size = 80.0;
    final avatarUrl = profile?.avatarUrl;

    Widget inner;
    if (isUploading) {
      inner = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: StarKidsColors.surfaceTertiary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      inner = ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _AvatarFallback(
            initials: profile?.initials ?? 'SK',
            size: size,
          ),
          errorWidget: (_, __, ___) => _AvatarFallback(
            initials: profile?.initials ?? 'SK',
            size: size,
          ),
        ),
      );
    } else {
      inner = _AvatarFallback(
        initials: profile?.initials ?? 'SK',
        size: size,
      );
    }

    return SizedBox(width: size, height: size, child: inner);
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: StarKidsColors.surfaceTertiary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: StarKidsColors.brandPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

// ─── Inline error banner ─────────────────────────────────────────────────────

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.lg,
        vertical: StarKidsSpacing.md,
      ),
      decoration: BoxDecoration(
        color: StarKidsColors.statusErrorSurface,
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        border: Border.all(
          color: StarKidsColors.statusError.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: StarKidsColors.statusError,
            size: 20,
          ),
          const SizedBox(width: StarKidsSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: StarKidsColors.textPrimary,
                  ),
            ),
          ),
          const SizedBox(width: StarKidsSpacing.xs),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              Icons.close_rounded,
              color: StarKidsColors.textSecondary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Child birth date picker ──────────────────────────────────────────────────

class _ChildBirthDateField extends StatelessWidget {
  const _ChildBirthDateField({
    required this.selectedDate,
    this.errorText,
    required this.onChanged,
  });

  final DateTime? selectedDate;
  final String? errorText;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = selectedDate ?? DateTime(now.year - 3, now.month, now.day);
    final firstDate = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? now : initial,
      firstDate: firstDate,
      lastDate: now,
      helpText: 'Дата рождения ребёнка',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = selectedDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _pickDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: StarKidsSpacing.lg,
              vertical: StarKidsSpacing.md,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: errorText != null
                    ? StarKidsColors.statusError
                    : StarKidsColors.borderDefault,
              ),
              borderRadius: BorderRadius.circular(StarKidsRadii.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Дата рождения ребёнка',
                        style: textTheme.bodySmall?.copyWith(
                          color: StarKidsColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d != null ? _formatDate(d) : 'Не указана',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: StarKidsColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: StarKidsSpacing.sm),
            child: Text(
              errorText!,
              style: textTheme.bodySmall?.copyWith(
                color: StarKidsColors.statusError,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Request preview item ─────────────────────────────────────────────────────

class _RequestPreviewItem extends StatelessWidget {
  const _RequestPreviewItem({required this.item});

  final RequestHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.md),
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(StarKidsRadii.sm),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.type.label,
                  style: textTheme.labelMedium?.copyWith(
                    color: StarKidsColors.textPrimary,
                  ),
                ),
                if (item.branch != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.branch!.name,
                    style: textTheme.bodySmall?.copyWith(
                      color: StarKidsColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: StarKidsSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: StarKidsColors.surfaceTertiary,
              borderRadius: BorderRadius.circular(StarKidsRadii.full),
            ),
            child: Text(
              item.status.label,
              style: textTheme.labelSmall?.copyWith(
                color: StarKidsColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Settings section widgets ─────────────────────────────────────────────────

class _NotificationToggleRow extends StatelessWidget {
  const _NotificationToggleRow({required this.notificationsController});

  final MobileNotificationsController notificationsController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = notificationsController.status;
    final isGranted = status == NotificationPermissionStatus.granted;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Push-уведомления',
                style: textTheme.bodyLarge,
              ),
              Text(
                _labelForStatus(status),
                style: textTheme.bodySmall?.copyWith(
                  color: StarKidsColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: isGranted,
          activeColor: StarKidsColors.brandPrimary,
          onChanged: notificationsController.isBusy
              ? null
              : (value) {
                  if (value) {
                    notificationsController.requestPermission();
                  } else {
                    notificationsController.openSystemSettings();
                  }
                },
        ),
      ],
    );
  }

  String _labelForStatus(NotificationPermissionStatus status) {
    return switch (status) {
      NotificationPermissionStatus.unknown => 'Не запрашивалось',
      NotificationPermissionStatus.granted => 'Включены',
      NotificationPermissionStatus.denied => 'Выключены',
      NotificationPermissionStatus.unavailable => 'Недоступно',
    };
  }
}

class _LanguagePlaceholderRow extends StatelessWidget {
  const _LanguagePlaceholderRow();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Язык', style: textTheme.bodyLarge),
              Text(
                'Скоро появится переключение языка.',
                style: textTheme.bodySmall?.copyWith(
                  color: StarKidsColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: StarKidsSpacing.md,
            vertical: StarKidsSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: StarKidsColors.borderDefault.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
          ),
          child: Text(
            'Рус / Қаз',
            style: textTheme.labelMedium?.copyWith(
              color: StarKidsColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
