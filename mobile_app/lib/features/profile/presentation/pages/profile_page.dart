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
    _notificationsController =
        widget.notificationsController ?? ServiceRegistry.mobileNotificationsController;
    _childrenController =
        widget.childrenControllerOverride ?? ServiceRegistry.childrenController;
    _settingsController =
        widget.settingsControllerOverride ?? ServiceRegistry.appSettingsController;

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
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? StarKidsDarkColors.surfaceCanvas : StarKidsColors.surfaceCanvas;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(l.profileTitle),
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
            ProfileViewStatus.empty || ProfileViewStatus.success => _buildContent(context),
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
          _ProfileHeaderCard(
            profile: profile,
            isUploadingAvatar: _controller.isUploadingAvatar,
            onPickAvatar: _pickAndUploadAvatar,
            onDeleteAvatar: (profile?.hasAvatar ?? false) ? _handleDeleteAvatar : null,
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
        StarKidsButton.secondary(
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
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.noChildren, style: textTheme.bodyMedium),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsButton.primary(
              label: l.addChild,
              onPressed: () => _showAddChildSheet(context),
            ),
          ],
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
              const SizedBox(height: StarKidsSpacing.sm),
            ],
            const SizedBox(height: StarKidsSpacing.sm),
            StarKidsButton.secondary(
              label: l.addChild,
              onPressed: () => _showAddChildSheet(context),
            ),
          ],
        );
    }

    return ProfileSectionCard(
      title: l.children,
      child: content,
    );
  }

  void _showAddChildSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(StarKidsRadii.xl)),
      ),
      builder: (_) => _ChildFormSheet(
        controller: controller,
        childToEdit: null,
      ),
    );
  }

  void _showEditChildSheet(BuildContext context, Child child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(StarKidsRadii.xl)),
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.deleteChild(child.id);
            },
            child: Text(l.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
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

    final cardBg = isDark ? StarKidsDarkColors.surfaceElevated : StarKidsColors.surfacePrimary;
    final cardBorder =
        isDark ? StarKidsDarkColors.borderDefault : StarKidsColors.borderDefault;
    final avatarBg = isDark
        ? StarKidsDarkColors.glassSurface
        : (child.gender == ChildGender.female
            ? StarKidsColors.surfaceTertiary
            : StarKidsColors.cosmicSky);
    final avatarEmoji = child.gender == ChildGender.female ? '👧' : '👦';

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
            child: Center(
              child: Text(avatarEmoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: StarKidsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatDate(child.birthDate),
                  style: textTheme.bodySmall,
                ),
                Text(
                  child.gender == ChildGender.female ? l.genderGirl : l.genderBoy,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: l.edit,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: l.delete,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
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
      setState(() => _birthDate = picked);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? StarKidsDarkColors.surfacePrimary : StarKidsColors.surfacePrimary;
    final isEditing = widget.childToEdit != null;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Container(
          color: sheetBg,
          padding: EdgeInsets.only(
            left: StarKidsSpacing.xl,
            right: StarKidsSpacing.xl,
            top: StarKidsSpacing.xl,
            bottom: MediaQuery.of(context).viewInsets.bottom + StarKidsSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? StarKidsDarkColors.borderDefault
                        : StarKidsColors.borderDefault,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: StarKidsSpacing.lg),
              Text(
                isEditing ? l.editChild : l.addChild,
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: StarKidsSpacing.xl),
              // Name
              StarKidsInputField(
                controller: _nameController,
                label: l.childName,
                errorText: _nameError,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: StarKidsSpacing.md),
              // Birth date
              _DatePickerField(
                label: l.childBirthDate,
                selectedDate: _birthDate,
                errorText: _birthDateError,
                dateLabel: _birthDate != null ? _formatDate(_birthDate!) : l.dateNotSet,
                onTap: () => _pickDate(context, l),
              ),
              const SizedBox(height: StarKidsSpacing.md),
              // Gender
              _GenderSelector(
                selected: _gender,
                errorText: _genderError,
                onSelected: (g) => setState(() {
                  _gender = g;
                  _genderError = null;
                }),
              ),
              if (widget.controller.formError != null) ...[
                const SizedBox(height: StarKidsSpacing.md),
                Text(
                  widget.controller.formError!,
                  style: textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? StarKidsDarkColors.statusError
                        : StarKidsColors.statusError,
                  ),
                ),
              ],
              const SizedBox(height: StarKidsSpacing.xl),
              StarKidsButton.primary(
                label: l.save,
                isLoading: widget.controller.isSaving,
                onPressed: widget.controller.isSaving ? null : () => _submit(l),
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
        );
      },
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
        : (isDark ? StarKidsDarkColors.borderDefault : StarKidsColors.borderDefault);
    final fillColor =
        isDark ? StarKidsDarkColors.glassSurface : StarKidsColors.glassSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: StarKidsSpacing.lg,
              vertical: StarKidsSpacing.md,
            ),
            decoration: BoxDecoration(
              color: fillColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(StarKidsRadii.md),
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
                      const SizedBox(height: 2),
                      Text(dateLabel, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: isDark
                      ? StarKidsDarkColors.textSecondary
                      : StarKidsColors.textSecondary,
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
        Row(
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
    final selectedBg = isDark
        ? StarKidsDarkColors.navIndicator
        : StarKidsColors.brandPrimary.withValues(alpha: 0.08);
    final selectedBorder =
        isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary;
    final idleBg =
        isDark ? StarKidsDarkColors.glassSurface : StarKidsColors.glassSurface;
    final idleBorder =
        isDark ? StarKidsDarkColors.borderDefault : StarKidsColors.borderDefault;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: StarKidsSpacing.md,
          vertical: StarKidsSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : idleBg,
          borderRadius: BorderRadius.circular(StarKidsRadii.md),
          border: Border.all(
            color: isSelected ? selectedBorder : idleBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary)
                    : null,
              ),
            ),
          ],
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
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = profile;
    final cardBg = isDark ? StarKidsDarkColors.surfaceElevated : StarKidsColors.surfacePrimary;
    final cardBorder = isDark ? StarKidsDarkColors.borderDefault : StarKidsColors.borderDefault;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(color: cardBorder),
        boxShadow: isDark ? null : StarKidsShadows.depth1,
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
                  Text(p.phone!, style: textTheme.bodyMedium),
                ] else if (p?.email != null && p!.email!.isNotEmpty) ...[
                  const SizedBox(height: StarKidsSpacing.xs),
                  Text(p.email!, style: textTheme.bodyMedium),
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
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = profile?.avatarUrl;

    Widget inner;
    if (isUploading) {
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? StarKidsDarkColors.glassSurface : StarKidsColors.surfaceTertiary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? StarKidsDarkColors.glassSurface : StarKidsColors.surfaceTertiary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary,
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
            color: isDark ? StarKidsDarkColors.statusError : StarKidsColors.statusError,
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
              color: isDark ? StarKidsDarkColors.textSecondary : StarKidsColors.textSecondary,
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
    final bg = isDark ? StarKidsDarkColors.surfaceCanvas : StarKidsColors.surfaceCanvas;
    final border = isDark ? StarKidsDarkColors.borderDefault : StarKidsColors.borderDefault;
    final chipBg = isDark ? StarKidsDarkColors.glassSurface : StarKidsColors.surfaceTertiary;

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
                color: isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary,
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
    final activeBg = isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary;
    final idleBg = isDark ? StarKidsDarkColors.glassSurface : StarKidsColors.glassSurface;
    final border = isDark ? StarKidsDarkColors.borderDefault : StarKidsColors.borderDefault;
    final activeText = Colors.white;
    final idleText = isDark ? StarKidsDarkColors.textSecondary : StarKidsColors.textSecondary;

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
