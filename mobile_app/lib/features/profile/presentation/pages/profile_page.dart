import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/sk_tokens.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_bottom_sheet.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
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

    return Scaffold(
      appBar: GlassAppBar(
        leading: GlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l.profileTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
    final c = SKTheme.of(context).colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SKSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: c.danger, size: 48),
            const SizedBox(height: SKSpacing.x4),
            Text(
              l.profileLoadError,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SKSpacing.x2),
            Text(
              _controller.errorMessage ?? l.profileLoadErrorHint,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SKSpacing.x5),
            PrimaryButton(label: l.retry, onPressed: _controller.retry),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final profile = _controller.profile;
    final l = AppL10n.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SKSpacing.x5),
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
          const SizedBox(height: SKSpacing.x5),
          _StatRow(
            controller: _controller,
            childrenController: _childrenController,
          ),
          if (_controller.errorMessage != null) ...[
            const SizedBox(height: SKSpacing.x4),
            _InlineErrorBanner(
              message: _controller.errorMessage!,
              onDismiss: _controller.clearError,
            ),
          ],
          if (_childrenController.todaysBirthdays.isNotEmpty) ...[
            const SizedBox(height: SKSpacing.x5),
            for (final child in _childrenController.todaysBirthdays)
              _BirthdayReminderBanner(child: child),
          ],
          const SizedBox(height: SKSpacing.x5),
          StarKidsContentSwitcher(child: _buildPersonalDataSection(context)),
          const SizedBox(height: SKSpacing.x5),
          _buildChildrenSection(context),
          const SizedBox(height: SKSpacing.x5),
          _buildBranchSection(context),
          const SizedBox(height: SKSpacing.x5),
          _buildRequestsSection(context),
          const SizedBox(height: SKSpacing.x5),
          _buildSettingsSection(context),
          const SizedBox(height: SKSpacing.x6),
          _buildFooter(context, l),
          const SizedBox(height: SKSpacing.x5),
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
          const SizedBox(height: SKSpacing.x3),
          StarKidsInputField(
            controller: _lastNameTextController,
            label: l.lastName,
            errorText: _controller.lastNameError,
            onChanged: _controller.updateLastName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: SKSpacing.x3),
          StarKidsInputField(
            controller: _emailTextController,
            label: l.email,
            errorText: _controller.emailError,
            onChanged: _controller.updateEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: SKSpacing.x5),
          PrimaryButton(
            label: l.save,
            onPressed: (_controller.isSaving || !_controller.canSave)
                ? null
                : _handleSave,
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
            const SizedBox(height: SKSpacing.x1),
            Text(branch.address, style: textTheme.bodyMedium),
          ],
          if (branch.workingHours.isNotEmpty) ...[
            const SizedBox(height: SKSpacing.x1),
            Text(branch.workingHours, style: textTheme.bodySmall),
          ],
          const SizedBox(height: SKSpacing.x5),
          SecondaryButton(
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
            padding: EdgeInsets.all(SKSpacing.x4),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case ProfileRequestsStatus.error:
        content = Builder(
          builder: (context) {
            final c = SKTheme.of(context).colors;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _controller.requestsErrorMessage ?? l.requestsLoadError,
                  style: textTheme.bodyMedium?.copyWith(color: c.danger),
                ),
                const SizedBox(height: SKSpacing.x3),
                SecondaryButton(
                  label: l.retry,
                  onPressed: _controller.loadRequestPreview,
                ),
              ],
            );
          },
        );
      case ProfileRequestsStatus.empty:
        content = Text(l.noRequests, style: textTheme.bodyMedium);
      case ProfileRequestsStatus.success:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in _controller.previewRequests) ...[
              _RequestPreviewItem(item: item),
              const SizedBox(height: SKSpacing.x2),
            ],
            if (_controller.totalRequests > 3)
              Padding(
                padding: const EdgeInsets.only(top: SKSpacing.x1),
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
          const SizedBox(height: SKSpacing.x5),
          SecondaryButton(
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
          const SizedBox(height: SKSpacing.x4),
          _LanguageSwitchRow(settingsController: _settingsController),
          const SizedBox(height: SKSpacing.x4),
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
        Center(
          child: TextButton(
            onPressed: _handleLogout,
            child: Text(l.logout),
          ),
        ),
        if (version.isNotEmpty) ...[
          const SizedBox(height: SKSpacing.x2),
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
    final c = SKTheme.of(context).colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: SKSpacing.x3),
      child: Container(
        padding: const EdgeInsets.all(SKSpacing.x4),
        decoration: BoxDecoration(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(SKRadius.lg),
          border: Border.all(color: c.cta.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎂', style: TextStyle(fontSize: 28)),
            const SizedBox(width: SKSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.birthdayReminderTitle(child.name),
                    style: textTheme.titleMedium?.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SKSpacing.x1),
                  Text(
                    l.birthdayFreeEntry,
                    style: textTheme.bodyMedium?.copyWith(
                      color: c.cta,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.birthdayPackageHint,
                    style: textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
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
    final c = SKTheme.of(context).colors;

    Widget content;
    switch (controller.status) {
      case ChildrenStatus.loading:
        content = const Center(
          child: Padding(
            padding: EdgeInsets.all(SKSpacing.x4),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case ChildrenStatus.error:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.errorMessage ?? l.childrenLoadError,
              style: textTheme.bodyMedium?.copyWith(color: c.danger),
            ),
            const SizedBox(height: SKSpacing.x3),
            SecondaryButton(
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
              const SizedBox(height: SKSpacing.x4),
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
    final l = AppL10n.of(context);
    unawaited(showGlassBottomSheet<void>(
      context: context,
      title: l.addChildSheetTitle,
      initialSize: 0.85,
      maxSize: 0.95,
      builder: (ctx, _) => _ChildFormSheet(
        controller: controller,
        childToEdit: null,
      ),
    ));
  }

  void _showEditChildSheet(BuildContext context, Child child) {
    final l = AppL10n.of(context);
    unawaited(showGlassBottomSheet<void>(
      context: context,
      title: l.editChild,
      initialSize: 0.85,
      maxSize: 0.95,
      builder: (ctx, _) => _ChildFormSheet(
        controller: controller,
        childToEdit: child,
      ),
    ));
  }

  void _confirmDelete(BuildContext context, Child child) {
    final l = AppL10n.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDeleteChild),
        content: Text(child.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.deleteChild(child.id);
            },
            child: Text(l.delete),
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
    final c = SKTheme.of(context).colors;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.xl),
        border: Border.all(color: c.hairline, width: 0.5),
        boxShadow: SKShadows.sm,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -46,
            right: -26,
            child: _DecorativeCloud(
              width: 168,
              height: 132,
              color: c.accentSoft,
            ),
          ),
          Positioned(
            left: -36,
            bottom: -58,
            child: _DecorativeCloud(
              width: 184,
              height: 142,
              color: c.cta.withValues(alpha: 0.04),
            ),
          ),
          Positioned(
            left: 72,
            top: 22,
            child: _DecorativeCloud(
              width: 62,
              height: 62,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(SKSpacing.x5),
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
                        const SizedBox(height: SKSpacing.x2),
                        Text(
                          subtitle!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (trailing != null) ...[
                        const SizedBox(height: SKSpacing.x4),
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
                                  const SizedBox(height: SKSpacing.x2),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 420),
                                    child: Text(
                                      subtitle!,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: c.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: SKSpacing.x4),
                            trailing!,
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: SKSpacing.x5),
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
    final c = SKTheme.of(context).colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 460;

        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(SKRadius.xl),
            border: Border.all(color: c.hairline, width: 0.5),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -18,
                right: -20,
                child: _DecorativeCloud(
                  width: 118,
                  height: 84,
                  color: c.accentSoft,
                ),
              ),
              Positioned(
                left: -18,
                bottom: -22,
                child: _DecorativeCloud(
                  width: 120,
                  height: 90,
                  color: c.cta.withValues(alpha: 0.04),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(SKSpacing.x5),
                child: Flex(
                  direction: isCompact ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: isCompact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    if (isCompact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ChildAvatarBadge.placeholder(size: 76),
                          const SizedBox(height: SKSpacing.x3),
                          Text(
                            l.addChildSheetTitle,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: SKSpacing.x1),
                          Text(
                            l.childrenEmptyHint,
                            style: textTheme.bodyMedium?.copyWith(
                              color: c.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      )
                    else
                      Expanded(
                        child: Row(
                          children: [
                            const _ChildAvatarBadge.placeholder(size: 76),
                            const SizedBox(width: SKSpacing.x4),
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
                                  const SizedBox(height: SKSpacing.x1),
                                  Text(
                                    l.childrenEmptyHint,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: c.textSecondary,
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
                      width: isCompact ? 0 : SKSpacing.x4,
                      height: isCompact ? SKSpacing.x4 : 0,
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
    final c = SKTheme.of(context).colors;

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SKRadius.pill),
        child: Ink(
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(SKRadius.pill),
            border: Border.all(
              color: c.cta.withValues(alpha: 0.34),
              width: 1.4,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: SKSpacing.x4,
            vertical: 14,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 20, color: c.cta),
              const SizedBox(width: SKSpacing.x2),
              Text(
                l.add,
                style: textTheme.labelLarge?.copyWith(
                  color: c.cta,
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
    final c = SKTheme.of(context).colors;
    final l = AppL10n.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.xl),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -16,
            right: -12,
            child: _DecorativeCloud(
              width: 120,
              height: 86,
              color: c.accentSoft,
            ),
          ),
          Positioned(
            left: -20,
            bottom: -24,
            child: _DecorativeCloud(
              width: 112,
              height: 88,
              color: c.cta.withValues(alpha: 0.04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(SKSpacing.x5),
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
                        const SizedBox(width: SKSpacing.x4),
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
                                const SizedBox(height: SKSpacing.x2),
                                _HighlightedDateChip(
                                  label: l.childBirthDate,
                                  value: _formatDate(child.birthDate),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: SKSpacing.x2),
                        _ChildActionMenu(
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
                      ],
                    ),
                    const SizedBox(height: SKSpacing.x3),
                    Wrap(
                      spacing: SKSpacing.x2,
                      runSpacing: SKSpacing.x2,
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
    final c = SKTheme.of(context).colors;
    final gender = child?.gender;
    final emoji = placeholder
        ? '🧸'
        : gender == ChildGender.female
            ? '👧'
            : '👦';
    final ringColors = gender == ChildGender.female
        ? const [Color(0xFFF7D8F0), Color(0xFFE9DFFF)]
        : const [Color(0xFFDDF3FF), Color(0xFFE9E2FF)];

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: placeholder ? [c.accentSoft, c.elevated] : ringColors,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.elevated,
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
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SKSpacing.x3,
        vertical: SKSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: c.cta.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SKRadius.pill),
        border: Border.all(color: c.cta.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cake_rounded, size: 16, color: c.cta),
          const SizedBox(width: SKSpacing.x2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: c.cta,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: c.cta,
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
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SKSpacing.x3,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.pill),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c.textSecondary),
          const SizedBox(width: SKSpacing.x1),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
    final c = SKTheme.of(context).colors;

    return Container(
      decoration: BoxDecoration(
        color: c.elevated,
        shape: BoxShape.circle,
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      child: PopupMenuButton<_ChildCardMenuAction>(
        tooltip: '',
        padding: const EdgeInsets.all(10),
        icon: Icon(Icons.more_horiz_rounded, color: c.textPrimary),
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
                const SizedBox(width: SKSpacing.x2),
                Text(l.edit),
              ],
            ),
          ),
          PopupMenuItem(
            value: _ChildCardMenuAction.delete,
            child: Builder(
              builder: (context) {
                final c = SKTheme.of(context).colors;
                return Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: c.danger),
                    const SizedBox(width: SKSpacing.x2),
                    Text(
                      l.delete,
                      style: TextStyle(color: c.danger),
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
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final l = AppL10n.of(context);
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final c = SKTheme.of(context).colors;
        final isEditing = widget.childToEdit != null;

        final localTheme = theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            fillColor: c.elevated,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SKSpacing.x4,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SKRadius.lg),
              borderSide: BorderSide(color: c.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SKRadius.lg),
              borderSide: BorderSide(color: c.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SKRadius.lg),
              borderSide: BorderSide(color: c.cta, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SKRadius.lg),
              borderSide: BorderSide(color: c.danger, width: 1.8),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SKRadius.lg),
              borderSide: BorderSide(color: c.danger, width: 1.8),
            ),
          ),
        );

        return Theme(
          data: localTheme,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              SKSpacing.x4,
              SKSpacing.x4,
              SKSpacing.x4,
              SKSpacing.x4 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChildFormAvatar(gender: _gender),
                    const SizedBox(width: SKSpacing.x4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEditing ? l.editChild : l.addChildSheetTitle,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: SKSpacing.x1),
                          Text(
                            l.childFormHint,
                            style: textTheme.bodyMedium?.copyWith(
                              color: c.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SKSpacing.x5),
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
                const SizedBox(height: SKSpacing.x3),
                _DatePickerField(
                  label: l.childBirthDate,
                  selectedDate: _birthDate,
                  errorText: _birthDateError,
                  dateLabel: _birthDate != null
                      ? _formatDate(_birthDate!)
                      : l.dateNotSet,
                  onTap: () => _pickDate(context, l),
                ),
                const SizedBox(height: SKSpacing.x3),
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
                  const SizedBox(height: SKSpacing.x3),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SKSpacing.x3),
                    decoration: BoxDecoration(
                      color: c.dangerSoft,
                      borderRadius: BorderRadius.circular(SKRadius.lg),
                      border: Border.all(
                        color: c.danger.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      widget.controller.formError!,
                      style: textTheme.bodySmall?.copyWith(
                        color: c.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: SKSpacing.x5),
                PrimaryButton(
                  label: isEditing ? l.save : l.add,
                  onPressed:
                      widget.controller.isSaving ? null : () => _submit(l),
                ),
                const SizedBox(height: SKSpacing.x2),
                SecondaryButton(
                  label: l.cancel,
                  fullWidth: true,
                  onPressed: widget.controller.isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
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
    final c = SKTheme.of(context).colors;
    final emoji = gender == ChildGender.female
        ? '👧'
        : gender == ChildGender.male
            ? '👦'
            : '🧸';
    final colors = gender == ChildGender.female
        ? const [Color(0xFFF7DFF5), Color(0xFFE8E1FF)]
        : const [Color(0xFFDDF3FF), Color(0xFFE9E2FF)];

    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gender == null ? [c.accentSoft, c.elevated] : colors,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.elevated,
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
    final c = SKTheme.of(context).colors;
    final borderColor = errorText != null ? c.danger : c.hairline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(SKRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                color: c.elevated,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(SKRadius.lg),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: SKSpacing.x4,
                vertical: SKSpacing.x3,
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
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateLabel,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                selectedDate == null ? c.textSecondary : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SKSpacing.x3),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: c.cta,
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
            padding: const EdgeInsets.only(left: SKSpacing.x2),
            child: Text(
              errorText!,
              style: textTheme.bodySmall?.copyWith(color: c.danger),
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
    final c = SKTheme.of(context).colors;
    final l = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.childGender,
          style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: SKSpacing.x2),
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
                  const SizedBox(height: SKSpacing.x2),
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
                const SizedBox(width: SKSpacing.x2),
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
            padding: const EdgeInsets.only(left: SKSpacing.x2),
            child: Text(
              errorText!,
              style: textTheme.bodySmall?.copyWith(color: c.danger),
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
    final c = SKTheme.of(context).colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(SKSpacing.x3),
          decoration: BoxDecoration(
            color: isSelected ? c.cta.withValues(alpha: 0.08) : c.elevated,
            borderRadius: BorderRadius.circular(SKRadius.lg),
            border: Border.all(
              color: isSelected ? c.cta : c.hairline,
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
                  color: isSelected ? c.cta.withValues(alpha: 0.12) : c.bg,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: SKSpacing.x3),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? c.cta : null,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, size: 18, color: c.cta),
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
    final c = SKTheme.of(context).colors;
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
            style: TextStyle(
              fontFamily: SKTypography.display,
              fontSize: 26,
              height: 1.1,
              letterSpacing: -0.52,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: SK.s1),
          Text(
            emailOrPhone,
            textAlign: TextAlign.center,
            style: SKTextStyles.small
                .copyWith(fontSize: 13, color: c.textTertiary),
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
    final c = SKTheme.of(context).colors;
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
                color: c.elevated,
                shape: BoxShape.circle,
                border: Border.all(color: c.hairline),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: c.textPrimary,
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
    final c = SKTheme.of(context).colors;
    final avatarUrl = profile?.avatarUrl;

    Widget inner;
    if (isUploading) {
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.elevated, shape: BoxShape.circle),
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
            fontFamily: SKTypography.display,
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
    final c = SKTheme.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SKSpacing.x4,
        vertical: SKSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: BorderRadius.circular(SKRadius.md),
        border: Border.all(color: c.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: c.danger, size: 20),
          const SizedBox(width: SKSpacing.x2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: SKSpacing.x1),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, color: c.textSecondary, size: 18),
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
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(SKRadius.sm),
        border: Border.all(color: c.hairline),
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
              horizontal: SKSpacing.x2,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.pill),
            ),
            child: Text(
              item.status.label,
              style: textTheme.labelSmall?.copyWith(color: c.cta),
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
          activeThumbColor: SKTheme.of(context).colors.cta,
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
        Expanded(child: Text(l.language, style: textTheme.bodyLarge)),
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
        Expanded(child: Text(l.theme, style: textTheme.bodyLarge)),
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
    return SolidCard(
      padding: const EdgeInsets.all(SKSpacing.x4),
      radius: SKRadius.xl,
      child: Row(
        children: [
          _StatCell(
            value: controller.previewRequests.isEmpty
                ? '3'
                : controller.previewRequests.length.toString(),
            label: 'праздника',
          ),
          const _StatDivider(),
          _StatCell(
            value: childrenController.children.isEmpty
                ? '2'
                : childrenController.children.length.toString(),
            label: 'детей',
          ),
          const _StatDivider(),
          const _StatCell(value: '8 200', label: 'бонусов'),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: SKTypography.display,
              fontSize: 22,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.44,
              color: c.textPrimary,
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
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: SKTheme.of(context).colors.hairline,
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
    final c = SKTheme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.pill),
        border: Border.all(color: c.hairline),
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
                  horizontal: SKSpacing.x3,
                  vertical: SKSpacing.x1,
                ),
                decoration: BoxDecoration(
                  color: selected == options[i] ? c.cta : Colors.transparent,
                  borderRadius: BorderRadius.circular(SKRadius.pill),
                ),
                child: Text(
                  labels[i],
                  style: textTheme.labelMedium?.copyWith(
                    color:
                        selected == options[i] ? Colors.white : c.textSecondary,
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
