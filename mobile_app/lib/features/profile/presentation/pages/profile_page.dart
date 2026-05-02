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
import '../../../../core/design_system/foundations/sk_tokens.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_input_field.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../children/domain/child.dart';
import '../../../children/presentation/controllers/children_controller.dart';
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
    this.childrenControllerOverride,
    this.settingsControllerOverride,
    this.selectedBranchOverride,
    this.onOpenBranchSelection,
    this.onOpenAllRequests,
    this.onLogout,
    this.appVersionOverride,
  });

  final ProfileController? controller;
  final MobileNotificationsController? notificationsController;
  final ChildrenController? childrenControllerOverride;
  final AppSettingsController? settingsControllerOverride;
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
  late final ChildrenController _childrenController;
  late final AppSettingsController _settingsController;

  final _firstNameTextController = TextEditingController();
  final _lastNameTextController = TextEditingController();
  final _emailTextController = TextEditingController();

  bool _didInitTextControllers = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ServiceRegistry.profileController;
    _notificationsController = widget.notificationsController ??
        ServiceRegistry.mobileNotificationsController;
    _childrenController =
        widget.childrenControllerOverride ?? ServiceRegistry.childrenController;
    _settingsController = widget.settingsControllerOverride ??
        ServiceRegistry.appSettingsController;

    unawaited(_controller.load());
    unawaited(_notificationsController.bootstrap());
    unawaited(_childrenController.load());

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
    if (_controller.status == ProfileViewStatus.success &&
        !_didInitTextControllers) {
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
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? StarKidsDarkColors.surfaceCanvas
        : StarKidsColors.surfaceCanvas;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(l.profileTitle),
        centerTitle: true,
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _notificationsController,
          _childrenController,
          _settingsController,
        ]),
        builder: (context, _) {
          return switch (_controller.status) {
            ProfileViewStatus.loading => const ProfileLoadingSkeleton(),
            ProfileViewStatus.error => _buildErrorState(context),
            ProfileViewStatus.empty ||
            ProfileViewStatus.success =>
              _buildContent(context),
          };
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final l = AppL10n.of(context);
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
              l.profileLoadError,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: StarKidsSpacing.sm),
            Text(
              _controller.errorMessage ?? l.profileLoadErrorHint,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: StarKidsSpacing.xl),
            StarKidsButton.primary(
              label: l.retry,
              onPressed: _controller.retry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final profile = _controller.profile;
    final l = AppL10n.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: _ProfileHeaderCard(
              profile: profile,
              isUploadingAvatar: _controller.isUploadingAvatar,
              onPickAvatar: _pickAndUploadAvatar,
              onDeleteAvatar:
                  (profile?.hasAvatar ?? false) ? _handleDeleteAvatar : null,
            ),
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          _StatRow(
            controller: _controller,
            childrenController: _childrenController,
          ),
          if (_controller.errorMessage != null) ...[
            const SizedBox(height: StarKidsSpacing.lg),
            _InlineErrorBanner(
              message: _controller.errorMessage!,
              onDismiss: _controller.clearError,
            ),
          ],
          // Birthday reminders for today
          if (_childrenController.todaysBirthdays.isNotEmpty) ...[
            const SizedBox(height: StarKidsSpacing.xl),
            for (final child in _childrenController.todaysBirthdays)
              _BirthdayReminderBanner(child: child),
          ],
          const SizedBox(height: StarKidsSpacing.xl),
          StarKidsContentSwitcher(
            child: _buildPersonalDataSection(context),
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          _buildChildrenSection(context),
          const SizedBox(height: StarKidsSpacing.xl),
          _buildBranchSection(context),
          const SizedBox(height: StarKidsSpacing.xl),
          _buildRequestsSection(context),
          const SizedBox(height: StarKidsSpacing.xl),
          _buildSettingsSection(context),
          const SizedBox(height: StarKidsSpacing.x2l),
          _buildFooter(context, l),
          const SizedBox(height: StarKidsSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildPersonalDataSection(BuildContext context) {
    final l = AppL10n.of(context);
    return ProfileSectionCard(
      title: l.personalData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StarKidsInputField(
            controller: _firstNameTextController,
            label: l.firstName,
            errorText: _controller.firstNameError,
            onChanged: _controller.updateFirstName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          StarKidsInputField(
            controller: _lastNameTextController,
            label: l.lastName,
            errorText: _controller.lastNameError,
            onChanged: _controller.updateLastName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          StarKidsInputField(
            controller: _emailTextController,
            label: l.email,
            errorText: _controller.emailError,
            onChanged: _controller.updateEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          StarKidsButton.primary(
            label: l.save,
            isLoading: _controller.isSaving,
            onPressed: _controller.canSave ? _handleSave : null,
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenSection(BuildContext context) {
    return _ChildrenSection(controller: _childrenController);
  }

  Widget _buildBranchSection(BuildContext context) {
    final l = AppL10n.of(context);
    final branch = _selectedBranch;
    final textTheme = Theme.of(context).textTheme;

    return ProfileSectionCard(
      title: l.myBranch,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.name,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (branch.address.isNotEmpty) ...[
            const SizedBox(height: StarKidsSpacing.xs),
            Text(branch.address, style: textTheme.bodyMedium),
          ],
          if (branch.workingHours.isNotEmpty) ...[
            const SizedBox(height: StarKidsSpacing.xs),
            Text(branch.workingHours, style: textTheme.bodySmall),
          ],
          const SizedBox(height: StarKidsSpacing.xl),
          StarKidsButton.secondary(
            label: l.changeBranch,
            onPressed: _handleOpenBranchSelection,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsSection(BuildContext context) {
    final l = AppL10n.of(context);
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
              _controller.requestsErrorMessage ?? l.requestsLoadError,
              style: textTheme.bodyMedium?.copyWith(
                color: StarKidsColors.statusError,
              ),
            ),
            const SizedBox(height: StarKidsSpacing.md),
            StarKidsButton.secondary(
              label: l.retry,
              onPressed: _controller.loadRequestPreview,
            ),
          ],
        );
      case ProfileRequestsStatus.empty:
        content = Text(l.noRequests, style: textTheme.bodyMedium);
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
                  l.moreRequests(_controller.totalRequests - 3),
                  style: textTheme.bodySmall,
                ),
              ),
          ],
        );
    }

    return ProfileSectionCard(
      title: l.myRequests,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          const SizedBox(height: StarKidsSpacing.xl),
          StarKidsButton.secondary(
            label: l.allRequests,
            onPressed: _handleOpenAllRequests,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final l = AppL10n.of(context);
    return ProfileSectionCard(
      title: l.settings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotificationToggleRow(
            notificationsController: _notificationsController,
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          _LanguageSwitchRow(settingsController: _settingsController),
          const SizedBox(height: StarKidsSpacing.lg),
          _ThemeSwitchRow(settingsController: _settingsController),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppL10n l) {
    final textTheme = Theme.of(context).textTheme;
    final version = widget.appVersionOverride ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StarKidsButton.ghost(
          label: l.logout,
          onPressed: _handleLogout,
        ),
        if (version.isNotEmpty) ...[
          const SizedBox(height: StarKidsSpacing.sm),
          Text(
            '${l.version} $version',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ─── Birthday reminder banner ─────────────────────────────────────────────────

class _BirthdayReminderBanner extends StatelessWidget {
  const _BirthdayReminderBanner({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: StarKidsSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(StarKidsSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF3D0A3F),
                    const Color(0xFF1A0A2E),
                  ]
                : [
                    StarKidsColors.brandPrimary.withValues(alpha: 0.08),
                    StarKidsColors.cosmicLavender,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(StarKidsRadii.lg),
          border: Border.all(
            color: isDark
                ? StarKidsDarkColors.accentPink.withValues(alpha: 0.4)
                : StarKidsColors.brandPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎂', style: TextStyle(fontSize: 28)),
            const SizedBox(width: StarKidsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.birthdayReminderTitle(child.name),
                    style: textTheme.titleMedium?.copyWith(
                      color: isDark
                          ? StarKidsDarkColors.textPrimary
                          : StarKidsColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.xs),
                  Text(
                    l.birthdayFreeEntry,
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? StarKidsDarkColors.accentPink
                          : StarKidsColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.birthdayPackageHint,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? StarKidsDarkColors.textSecondary
                          : StarKidsColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Children section ─────────────────────────────────────────────────────────

class _ChildrenSection extends StatelessWidget {
  const _ChildrenSection({required this.controller});

  final ChildrenController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;
    switch (controller.status) {
      case ChildrenStatus.loading:
        content = const Center(
          child: Padding(
            padding: EdgeInsets.all(StarKidsSpacing.lg),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case ChildrenStatus.error:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.errorMessage ?? l.childrenLoadError,
              style: textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? StarKidsDarkColors.statusError
                    : StarKidsColors.statusError,
              ),
            ),
            const SizedBox(height: StarKidsSpacing.md),
            StarKidsButton.secondary(
              label: l.retry,
              onPressed: controller.retry,
            ),
          ],
        );
      case ChildrenStatus.empty:
        content = _ChildrenEmptyState(
          onAdd: () => _showAddChildSheet(context),
        );
      case ChildrenStatus.success:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final child in controller.children) ...[
              _ChildCard(
                child: child,
                onEdit: () => _showEditChildSheet(context, child),
                onDelete: () => _confirmDelete(context, child),
              ),
              const SizedBox(height: StarKidsSpacing.lg),
            ],
          ],
        );
    }

    return _ChildrenSectionFrame(
      title: l.children,
      subtitle: null,
      trailing: controller.status == ChildrenStatus.success
          ? _AddChildButton(onTap: () => _showAddChildSheet(context))
          : null,
      child: content,
    );
  }

  void _showAddChildSheet(BuildContext context) {
    showStarKidsModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(StarKidsRadii.xl)),
      ),
      builder: (_) => _ChildFormSheet(
        controller: controller,
        childToEdit: null,
      ),
    );
  }

  void _showEditChildSheet(BuildContext context, Child child) {
    showStarKidsModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(StarKidsRadii.xl)),
      ),
      builder: (_) => _ChildFormSheet(
        controller: controller,
        childToEdit: child,
      ),
    );
  }

  void _confirmDelete(BuildContext context, Child child) {
    final l = AppL10n.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDeleteChild),
        content: Text(child.name),
        actions: [
          StarKidsButton.ghost(
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(),
            label: l.cancel,
          ),
          StarKidsButton.ghost(
            expand: false,
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.deleteChild(child.id);
            },
            label: l.delete,
          ),
        ],
      ),
    );
  }
}

class _ChildrenSectionFrame extends StatelessWidget {
  const _ChildrenSectionFrame({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBorder =
        isDark ? StarKidsDarkColors.borderDefault : const Color(0xFFE7D8F7);

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1B1732),
                  StarKidsDarkColors.surfaceElevated,
                ]
              : [
                  StarKidsColors.surfacePrimary,
                  const Color(0xFFFFFBFF),
                ],
        ),
        borderRadius: BorderRadius.circular(StarKidsRadii.xl + 4),
        border: Border.all(color: cardBorder),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ]
            : StarKidsShadows.depth1,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -46,
            right: -26,
            child: _DecorativeCloud(
              width: 168,
              height: 132,
              color: isDark
                  ? StarKidsDarkColors.accentPink.withValues(alpha: 0.12)
                  : const Color(0xFFEDE0FF),
            ),
          ),
          Positioned(
            left: -36,
            bottom: -58,
            child: _DecorativeCloud(
              width: 184,
              height: 142,
              color: isDark ? const Color(0x224D9FFF) : const Color(0xFFF1E8FF),
            ),
          ),
          Positioned(
            left: 72,
            top: 22,
            child: _DecorativeCloud(
              width: 62,
              height: 62,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.68),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(StarKidsSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 480;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCompact) ...[
                      Text(
                        title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: StarKidsSpacing.sm),
                        Text(
                          subtitle!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? StarKidsDarkColors.textSecondary
                                : StarKidsColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (trailing != null) ...[
                        const SizedBox(height: StarKidsSpacing.lg),
                        Align(
                            alignment: Alignment.centerLeft, child: trailing!),
                      ],
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: StarKidsSpacing.sm),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 420),
                                    child: Text(
                                      subtitle!,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: isDark
                                            ? StarKidsDarkColors.textSecondary
                                            : StarKidsColors.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: StarKidsSpacing.lg),
                            trailing!,
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: StarKidsSpacing.xl),
                    child,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildrenEmptyState extends StatelessWidget {
  const _ChildrenEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.78);
    final panelBorder =
        isDark ? StarKidsDarkColors.borderDefault : const Color(0xFFE9DCF8);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 460;

        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(StarKidsRadii.xl),
            border: Border.all(color: panelBorder),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -18,
                right: -20,
                child: _DecorativeCloud(
                  width: 118,
                  height: 84,
                  color: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0xFFF3E8FF),
                ),
              ),
              Positioned(
                left: -18,
                bottom: -22,
                child: _DecorativeCloud(
                  width: 120,
                  height: 90,
                  color: isDark
                      ? const Color(0x224D9FFF)
                      : const Color(0xFFE8F0FF),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(StarKidsSpacing.xl),
                child: Flex(
                  direction: isCompact ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: isCompact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    if (isCompact)
                      Row(
                        children: [
                          const _ChildAvatarBadge.placeholder(size: 76),
                          const SizedBox(width: StarKidsSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l.addChildSheetTitle,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: StarKidsSpacing.xs),
                                Text(
                                  l.childrenEmptyHint,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? StarKidsDarkColors.textSecondary
                                        : StarKidsColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Expanded(
                        child: Row(
                          children: [
                            const _ChildAvatarBadge.placeholder(size: 76),
                            const SizedBox(width: StarKidsSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l.addChildSheetTitle,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: StarKidsSpacing.xs),
                                  Text(
                                    l.childrenEmptyHint,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? StarKidsDarkColors.textSecondary
                                          : StarKidsColors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: isCompact ? 0 : StarKidsSpacing.lg,
                      height: isCompact ? StarKidsSpacing.lg : 0,
                    ),
                    _AddChildButton(onTap: onAdd, expand: isCompact),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddChildButton extends StatelessWidget {
  const _AddChildButton({
    required this.onTap,
    this.expand = false,
  });

  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? StarKidsDarkColors.accentPink.withValues(alpha: 0.54)
        : StarKidsColors.brandPrimary.withValues(alpha: 0.34);
    final fillColor = isDark
        ? StarKidsDarkColors.accentPink.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.96);
    final fgColor =
        isDark ? StarKidsDarkColors.textPrimary : StarKidsColors.brandPrimary;

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
        child: Ink(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: StarKidsSpacing.lg,
            vertical: 14,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 20, color: fgColor),
              const SizedBox(width: StarKidsSpacing.sm),
              Text(
                l.add,
                style: textTheme.labelLarge?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 138),
      child: button,
    );
  }
}

class _DecorativeCloud extends StatelessWidget {
  const _DecorativeCloud({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height),
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  final Child child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : const Color(0xFFE8DBF7),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -16,
            right: -12,
            child: _DecorativeCloud(
              width: 120,
              height: 86,
              color: isDark
                  ? StarKidsDarkColors.accentPink.withValues(alpha: 0.10)
                  : const Color(0xFFF0E3FF),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -24,
            child: _DecorativeCloud(
              width: 112,
              height: 88,
              color: isDark ? const Color(0x224D9FFF) : const Color(0xFFE5F1FF),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(StarKidsSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final genderLabel = child.gender == ChildGender.female
                    ? l.genderGirl
                    : l.genderBoy;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChildAvatarBadge(child: child, size: 76),
                        const SizedBox(width: StarKidsSpacing.lg),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: StarKidsSpacing.sm),
                                _HighlightedDateChip(
                                  label: l.childBirthDate,
                                  value: _formatDate(child.birthDate),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: StarKidsSpacing.sm),
                        _ChildActionMenu(
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
                      ],
                    ),
                    const SizedBox(height: StarKidsSpacing.md),
                    Wrap(
                      spacing: StarKidsSpacing.sm,
                      runSpacing: StarKidsSpacing.sm,
                      children: [
                        _SoftMetaChip(
                          icon: child.gender == ChildGender.female
                              ? Icons.girl_rounded
                              : Icons.boy_rounded,
                          label: genderLabel,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

enum _ChildCardMenuAction { edit, delete }

class _ChildAvatarBadge extends StatelessWidget {
  const _ChildAvatarBadge({
    required this.child,
    required this.size,
  }) : placeholder = false;

  const _ChildAvatarBadge.placeholder({
    required this.size,
  })  : child = null,
        placeholder = true;

  final Child? child;
  final double size;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gender = child?.gender;
    final emoji = placeholder
        ? '🧸'
        : gender == ChildGender.female
            ? '👧'
            : '👦';
    final ringColors = isDark
        ? [
            StarKidsDarkColors.accentPink.withValues(alpha: 0.34),
            const Color(0x334D9FFF),
          ]
        : gender == ChildGender.female
            ? [
                const Color(0xFFF7D8F0),
                const Color(0xFFE9DFFF),
              ]
            : [
                const Color(0xFFDDF3FF),
                const Color(0xFFE9E2FF),
              ];

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ringColors,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF241E42) : Colors.white,
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: size * 0.38),
          ),
        ),
      ),
    );
  }
}

class _HighlightedDateChip extends StatelessWidget {
  const _HighlightedDateChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.md,
        vertical: StarKidsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cake_rounded, size: 16, color: accent),
          const SizedBox(width: StarKidsSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftMetaChip extends StatelessWidget {
  const _SoftMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8F2FF),
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : const Color(0xFFE7DCF8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark
                ? StarKidsDarkColors.textSecondary
                : StarKidsColors.textSecondary,
          ),
          const SizedBox(width: StarKidsSpacing.xs),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildActionMenu extends StatelessWidget {
  const _ChildActionMenu({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.94);
    final menuBorder =
        isDark ? StarKidsDarkColors.borderDefault : const Color(0xFFE8DBF7);

    return Container(
      decoration: BoxDecoration(
        color: menuBg,
        shape: BoxShape.circle,
        border: Border.all(color: menuBorder),
      ),
      child: PopupMenuButton<_ChildCardMenuAction>(
        tooltip: '',
        padding: const EdgeInsets.all(10),
        icon: Icon(
          Icons.more_horiz_rounded,
          color: isDark
              ? StarKidsDarkColors.textPrimary
              : StarKidsColors.textPrimary,
        ),
        onSelected: (value) {
          switch (value) {
            case _ChildCardMenuAction.edit:
              onEdit();
              break;
            case _ChildCardMenuAction.delete:
              onDelete();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _ChildCardMenuAction.edit,
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: StarKidsSpacing.sm),
                Text(l.edit),
              ],
            ),
          ),
          PopupMenuItem(
            value: _ChildCardMenuAction.delete,
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: StarKidsColors.statusError,
                ),
                const SizedBox(width: StarKidsSpacing.sm),
                Text(
                  l.delete,
                  style: const TextStyle(color: StarKidsColors.statusError),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Child form sheet ─────────────────────────────────────────────────────────

class _ChildFormSheet extends StatefulWidget {
  const _ChildFormSheet({
    required this.controller,
    required this.childToEdit,
  });

  final ChildrenController controller;
  final Child? childToEdit;

  @override
  State<_ChildFormSheet> createState() => _ChildFormSheetState();
}

class _ChildFormSheetState extends State<_ChildFormSheet> {
  late final TextEditingController _nameController;
  DateTime? _birthDate;
  ChildGender? _gender;

  String? _nameError;
  String? _birthDateError;
  String? _genderError;

  @override
  void initState() {
    super.initState();
    final child = widget.childToEdit;
    _nameController = TextEditingController(text: child?.name ?? '');
    _birthDate = child?.birthDate;
    _gender = child?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _validate(AppL10n l) {
    bool ok = true;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameError = l.childNameRequired;
      ok = false;
    } else if (name.length > 100) {
      _nameError = l.childNameTooLong;
      ok = false;
    } else {
      _nameError = null;
    }

    if (_birthDate == null) {
      _birthDateError = l.childBirthDateRequired;
      ok = false;
    } else {
      final now = DateTime.now();
      if (_birthDate!.isAfter(now)) {
        _birthDateError = l.childBirthDateFuture;
        ok = false;
      } else {
        _birthDateError = null;
      }
    }

    if (_gender == null) {
      _genderError = l.childGenderRequired;
      ok = false;
    } else {
      _genderError = null;
    }

    setState(() {});
    return ok;
  }

  Future<void> _submit(AppL10n l) async {
    if (!_validate(l)) return;

    bool success;
    if (widget.childToEdit != null) {
      success = await widget.controller.editChild(
        childId: widget.childToEdit!.id,
        name: _nameController.text.trim(),
        birthDate: _birthDate!,
        gender: _gender!,
      );
    } else {
      success = await widget.controller.addChild(
        name: _nameController.text.trim(),
        birthDate: _birthDate!,
        gender: _gender!,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDate(BuildContext context, AppL10n l) async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 3);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 18),
      lastDate: now,
      helpText: l.datePickerHelpText,
      cancelText: l.datePickerCancel,
      confirmText: l.datePickerConfirm,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateError = null;
      });
      widget.controller.clearFormError();
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.childToEdit != null;
    final fieldFill =
        isDark ? const Color(0xFF221D3F) : const Color(0xFFFDF9FF);
    final fieldBorder =
        isDark ? StarKidsDarkColors.borderDefault : const Color(0xFFE7D8F7);
    final localTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: StarKidsSpacing.lg,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StarKidsRadii.lg),
          borderSide: BorderSide(color: fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StarKidsRadii.lg),
          borderSide: BorderSide(color: fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StarKidsRadii.lg),
          borderSide: BorderSide(
            color: isDark
                ? StarKidsDarkColors.accentPink
                : StarKidsColors.brandPrimary,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StarKidsRadii.lg),
          borderSide: BorderSide(
            color: isDark
                ? StarKidsDarkColors.borderError
                : StarKidsColors.borderError,
            width: 1.8,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StarKidsRadii.lg),
          borderSide: BorderSide(
            color: isDark
                ? StarKidsDarkColors.borderError
                : StarKidsColors.borderError,
            width: 1.8,
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Theme(
          data: localTheme,
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: StarKidsSpacing.lg,
                right: StarKidsSpacing.lg,
                top: StarKidsSpacing.lg,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    StarKidsSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                StarKidsDarkColors.surfacePrimary,
                                const Color(0xFF1D1936),
                              ]
                            : [
                                StarKidsColors.surfacePrimary,
                                const Color(0xFFFFFBFF),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(StarKidsRadii.x2l),
                      border: Border.all(color: fieldBorder),
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.26),
                                blurRadius: 28,
                                offset: const Offset(0, 16),
                              ),
                            ]
                          : StarKidsShadows.depth1,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -28,
                          right: -24,
                          child: _DecorativeCloud(
                            width: 156,
                            height: 112,
                            color: isDark
                                ? StarKidsDarkColors.accentPink
                                    .withValues(alpha: 0.10)
                                : const Color(0xFFF0E3FF),
                          ),
                        ),
                        Positioned(
                          left: -26,
                          bottom: -30,
                          child: _DecorativeCloud(
                            width: 144,
                            height: 112,
                            color: isDark
                                ? const Color(0x224D9FFF)
                                : const Color(0xFFE6F0FF),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(StarKidsSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 42,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? StarKidsDarkColors.borderStrong
                                        : StarKidsColors.borderStrong,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: StarKidsSpacing.lg),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ChildFormAvatar(gender: _gender),
                                  const SizedBox(width: StarKidsSpacing.lg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isEditing
                                              ? l.editChild
                                              : l.addChildSheetTitle,
                                          style: textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: StarKidsSpacing.xs,
                                        ),
                                        Text(
                                          l.childFormHint,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: isDark
                                                ? StarKidsDarkColors
                                                    .textSecondary
                                                : StarKidsColors.textSecondary,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: StarKidsSpacing.xl),
                              StarKidsInputField(
                                controller: _nameController,
                                label: l.childName,
                                errorText: _nameError,
                                onChanged: (_) {
                                  if (_nameError != null) {
                                    setState(() => _nameError = null);
                                  }
                                  widget.controller.clearFormError();
                                },
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: StarKidsSpacing.md),
                              _DatePickerField(
                                label: l.childBirthDate,
                                selectedDate: _birthDate,
                                errorText: _birthDateError,
                                dateLabel: _birthDate != null
                                    ? _formatDate(_birthDate!)
                                    : l.dateNotSet,
                                onTap: () => _pickDate(context, l),
                              ),
                              const SizedBox(height: StarKidsSpacing.md),
                              _GenderSelector(
                                selected: _gender,
                                errorText: _genderError,
                                onSelected: (g) => setState(() {
                                  _gender = g;
                                  _genderError = null;
                                  widget.controller.clearFormError();
                                }),
                              ),
                              if (widget.controller.formError != null) ...[
                                const SizedBox(height: StarKidsSpacing.md),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(
                                    StarKidsSpacing.md,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? StarKidsDarkColors.statusError
                                            : StarKidsColors.statusError)
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(
                                      StarKidsRadii.lg,
                                    ),
                                    border: Border.all(
                                      color: isDark
                                          ? StarKidsDarkColors.statusError
                                              .withValues(alpha: 0.22)
                                          : StarKidsColors.statusError
                                              .withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Text(
                                    widget.controller.formError!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? StarKidsDarkColors.statusError
                                          : StarKidsColors.statusError,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: StarKidsSpacing.xl),
                              StarKidsButton.primary(
                                label: isEditing ? l.save : l.add,
                                isLoading: widget.controller.isSaving,
                                onPressed: widget.controller.isSaving
                                    ? null
                                    : () => _submit(l),
                              ),
                              const SizedBox(height: StarKidsSpacing.sm),
                              StarKidsButton.secondary(
                                label: l.cancel,
                                onPressed: widget.controller.isSaving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChildFormAvatar extends StatelessWidget {
  const _ChildFormAvatar({required this.gender});

  final ChildGender? gender;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emoji = gender == ChildGender.female
        ? '👧'
        : gender == ChildGender.male
            ? '👦'
            : '🧸';
    final colors = isDark
        ? [
            StarKidsDarkColors.accentPink.withValues(alpha: 0.32),
            const Color(0x334D9FFF),
          ]
        : [
            const Color(0xFFF7DFF5),
            const Color(0xFFE8E1FF),
          ];

    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF241E42) : Colors.white,
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.selectedDate,
    required this.errorText,
    required this.dateLabel,
    required this.onTap,
  });

  final String label;
  final DateTime? selectedDate;
  final String? errorText;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = errorText != null
        ? (isDark ? StarKidsDarkColors.borderError : StarKidsColors.borderError)
        : (isDark ? StarKidsDarkColors.borderDefault : const Color(0xFFE7D8F7));
    final fillColor =
        isDark ? const Color(0xFF221D3F) : const Color(0xFFFDF9FF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(StarKidsRadii.lg),
            child: Ink(
              decoration: BoxDecoration(
                color: fillColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(StarKidsRadii.lg),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: StarKidsSpacing.lg,
                vertical: StarKidsSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? StarKidsDarkColors.textSecondary
                                : StarKidsColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateLabel,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selectedDate == null
                                ? (isDark
                                    ? StarKidsDarkColors.textSecondary
                                    : StarKidsColors.textSecondary)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: StarKidsSpacing.md),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF7EEFF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: isDark
                          ? StarKidsDarkColors.textSecondary
                          : StarKidsColors.brandPrimary,
                    ),
                  ),
                ],
              ),
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
                color: isDark
                    ? StarKidsDarkColors.statusError
                    : StarKidsColors.statusError,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
    required this.selected,
    required this.errorText,
    required this.onSelected,
  });

  final ChildGender? selected;
  final String? errorText;
  final ValueChanged<ChildGender> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.childGender,
          style: textTheme.bodySmall?.copyWith(
            color: isDark
                ? StarKidsDarkColors.textSecondary
                : StarKidsColors.textSecondary,
          ),
        ),
        const SizedBox(height: StarKidsSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;

            if (isCompact) {
              return Column(
                children: [
                  _GenderOption(
                    label: l.genderBoy,
                    emoji: '👦',
                    isSelected: selected == ChildGender.male,
                    onTap: () => onSelected(ChildGender.male),
                  ),
                  const SizedBox(height: StarKidsSpacing.sm),
                  _GenderOption(
                    label: l.genderGirl,
                    emoji: '👧',
                    isSelected: selected == ChildGender.female,
                    onTap: () => onSelected(ChildGender.female),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _GenderOption(
                    label: l.genderBoy,
                    emoji: '👦',
                    isSelected: selected == ChildGender.male,
                    onTap: () => onSelected(ChildGender.male),
                  ),
                ),
                const SizedBox(width: StarKidsSpacing.sm),
                Expanded(
                  child: _GenderOption(
                    label: l.genderGirl,
                    emoji: '👧',
                    isSelected: selected == ChildGender.female,
                    onTap: () => onSelected(ChildGender.female),
                  ),
                ),
              ],
            );
          },
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: StarKidsSpacing.sm),
            child: Text(
              errorText!,
              style: textTheme.bodySmall?.copyWith(
                color: isDark
                    ? StarKidsDarkColors.statusError
                    : StarKidsColors.statusError,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary;
    final selectedBg = isDark
        ? StarKidsDarkColors.accentPink.withValues(alpha: 0.12)
        : StarKidsColors.brandPrimary.withValues(alpha: 0.08);
    final selectedBorder = accent;
    final idleBg = isDark ? const Color(0xFF221D3F) : const Color(0xFFFDF9FF);
    final idleBorder =
        isDark ? StarKidsDarkColors.borderDefault : const Color(0xFFE7D8F7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(StarKidsSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : idleBg,
            borderRadius: BorderRadius.circular(StarKidsRadii.lg),
            border: Border.all(
              color: isSelected ? selectedBorder : idleBorder,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? accent.withValues(alpha: 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: StarKidsSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? accent : null,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: accent,
                ),
            ],
          ),
        ),
      ),
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
    final p = profile;
    final name =
        p?.fullName.trim().isNotEmpty == true ? p!.fullName : 'Айгерим А.';
    final emailOrPhone = p?.email?.isNotEmpty == true
        ? p!.email!
        : (p?.phone?.isNotEmpty == true ? p!.phone! : 'family@starkids.kz');

    return Padding(
      padding: const EdgeInsets.only(top: SK.s3),
      child: Column(
        children: [
          _AvatarSection(
            profile: p,
            isUploading: isUploadingAvatar,
            onPickAvatar: onPickAvatar,
            onDeleteAvatar: onDeleteAvatar,
          ),
          const SizedBox(height: SK.s4),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 26,
              height: 1.1,
              letterSpacing: -0.52,
              color: SK.ink,
            ),
          ),
          const SizedBox(height: SK.s1),
          Text(
            emailOrPhone,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              color: SK.ink3,
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
              decoration: BoxDecoration(
                color: SK.bgElev,
                shape: BoxShape.circle,
                border: Border.all(color: SK.line),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: SK.ink,
                size: 15,
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
    const size = 84.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = profile?.avatarUrl;

    Widget inner;
    if (isUploading) {
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark
              ? StarKidsDarkColors.glassSurface
              : StarKidsColors.surfaceTertiary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2)),
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
      inner = _AvatarFallback(initials: profile?.initials ?? 'SK', size: size);
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB59E), Color(0xFFFF7676)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 32,
            color: Colors.white,
            fontWeight: FontWeight.w400,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.lg,
        vertical: StarKidsSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.statusErrorSurface
            : StarKidsColors.statusErrorSurface,
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.statusError.withValues(alpha: 0.3)
              : StarKidsColors.statusError.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: isDark
                ? StarKidsDarkColors.statusError
                : StarKidsColors.statusError,
            size: 20,
          ),
          const SizedBox(width: StarKidsSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: StarKidsSpacing.xs),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close_rounded,
              color: isDark
                  ? StarKidsDarkColors.textSecondary
                  : StarKidsColors.textSecondary,
              size: 18,
            ),
          ),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? StarKidsDarkColors.surfaceCanvas
        : StarKidsColors.surfaceCanvas;
    final border = isDark
        ? StarKidsDarkColors.borderDefault
        : StarKidsColors.borderDefault;
    final chipBg = isDark
        ? StarKidsDarkColors.glassSurface
        : StarKidsColors.surfaceTertiary;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(StarKidsRadii.sm),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.type.label, style: textTheme.labelMedium),
                if (item.branch != null) ...[
                  const SizedBox(height: 2),
                  Text(item.branch!.name, style: textTheme.bodySmall),
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
              color: chipBg,
              borderRadius: BorderRadius.circular(StarKidsRadii.full),
            ),
            child: Text(
              item.status.label,
              style: textTheme.labelSmall?.copyWith(
                color: isDark
                    ? StarKidsDarkColors.accentPink
                    : StarKidsColors.brandPrimary,
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
    final l = AppL10n.of(context);
    final status = notificationsController.status;
    final isGranted = status == NotificationPermissionStatus.granted;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.pushNotifications, style: textTheme.bodyLarge),
              Text(_labelForStatus(status, l), style: textTheme.bodySmall),
            ],
          ),
        ),
        Switch(
          value: isGranted,
          activeThumbColor: StarKidsColors.brandPrimary,
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

  String _labelForStatus(NotificationPermissionStatus status, AppL10n l) {
    return switch (status) {
      NotificationPermissionStatus.unknown => l.notifUnknown,
      NotificationPermissionStatus.granted => l.notifEnabled,
      NotificationPermissionStatus.denied => l.notifDisabled,
      NotificationPermissionStatus.unavailable => l.notifUnavailable,
    };
  }
}

class _LanguageSwitchRow extends StatelessWidget {
  const _LanguageSwitchRow({required this.settingsController});

  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l = AppL10n.of(context);
    final current = settingsController.locale;

    return Row(
      children: [
        Expanded(
          child: Text(l.language, style: textTheme.bodyLarge),
        ),
        _SegmentedChoice(
          options: const ['ru', 'kk'],
          labels: [l.langRu, l.langKk],
          selected: current,
          onChanged: (v) => settingsController.setLocale(v),
        ),
      ],
    );
  }
}

class _ThemeSwitchRow extends StatelessWidget {
  const _ThemeSwitchRow({required this.settingsController});

  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l = AppL10n.of(context);
    final isDark = settingsController.isDark;

    return Row(
      children: [
        Expanded(
          child: Text(l.theme, style: textTheme.bodyLarge),
        ),
        _SegmentedChoice(
          options: const ['light', 'dark'],
          labels: [l.themeLight, l.themeDark],
          selected: isDark ? 'dark' : 'light',
          onChanged: (v) => settingsController.setThemeMode(
            v == 'dark' ? ThemeMode.dark : ThemeMode.light,
          ),
        ),
      ],
    );
  }
}

// ─── Stat row ─────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.controller,
    required this.childrenController,
  });

  final ProfileController controller;
  final ChildrenController childrenController;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.glassSurface
            : StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : StarKidsColors.borderDefault,
        ),
      ),
      child: Row(
        children: [
          _StatCell(
            value: controller.previewRequests.isEmpty
                ? '3'
                : controller.previewRequests.length.toString(),
            label: 'праздника',
            isDark: isDark,
          ),
          _StatDivider(isDark: isDark),
          _StatCell(
            value: childrenController.children.isEmpty
                ? '2'
                : childrenController.children.length.toString(),
            label: 'детей',
            isDark: isDark,
          ),
          _StatDivider(isDark: isDark),
          _StatCell(
            value: '8 200',
            label: 'бонусов',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.isDark,
  });

  final String value;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 22,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.44,
              color: isDark
                  ? StarKidsDarkColors.textPrimary
                  : StarKidsColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: isDark
          ? StarKidsDarkColors.borderDefault
          : StarKidsColors.borderDefault,
    );
  }
}

class _SegmentedChoice extends StatelessWidget {
  const _SegmentedChoice({
    required this.options,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final activeBg =
        isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary;
    final idleBg =
        isDark ? StarKidsDarkColors.glassSurface : StarKidsColors.glassSurface;
    final border = isDark
        ? StarKidsDarkColors.borderDefault
        : StarKidsColors.borderDefault;
    const activeText = Colors.white;
    final idleText = isDark
        ? StarKidsDarkColors.textSecondary
        : StarKidsColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: idleBg,
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < options.length; i++)
            GestureDetector(
              onTap: () => onChanged(options[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: StarKidsSpacing.md,
                  vertical: StarKidsSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: selected == options[i] ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(StarKidsRadii.full),
                ),
                child: Text(
                  labels[i],
                  style: textTheme.labelMedium?.copyWith(
                    color: selected == options[i] ? activeText : idleText,
                    fontWeight: selected == options[i]
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
