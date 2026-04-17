import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_input_field.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/design_system/widgets/star_kids_select_field.dart';
import '../../../birthdays/domain/birthday_package.dart';
import '../../../branches/domain/branch_option.dart';
import '../../domain/birthday_request_submission.dart';
import '../../domain/contact_request_submission.dart';
import '../../domain/request_type.dart';
import '../controllers/birthday_request_form_controller.dart';
import '../controllers/contact_request_form_controller.dart';
import '../formatters/kz_phone_input_formatter.dart';
import '../models/request_page_args.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key, this.args});

  final RequestPageArgs? args;

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  final _birthdayFormKey = GlobalKey<FormState>();
  final _contactFormKey = GlobalKey<FormState>();
  late final BirthdayRequestFormController _birthdayController;
  late final ContactRequestFormController _contactController;
  late RequestType _selectedType;
  late final String? _contactContextLabel;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.args?.initialType ?? RequestType.birthdayRequest;
    _contactContextLabel = widget.args?.initialContactContextLabel;
    _birthdayController = BirthdayRequestFormController(
      repository: ServiceRegistry.birthdayRequestRepository,
      packageRepository: ServiceRegistry.birthdayPackageRepository,
      initialPackageId: widget.args?.initialPackageId,
      initialPackage: widget.args?.initialPackage,
    );
    _contactController = ContactRequestFormController(
      repository: ServiceRegistry.contactRequestRepository,
      initialMessage: widget.args?.initialContactMessage,
    );
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _birthdayController,
        _contactController,
        ServiceRegistry.selectedBranchController,
      ]),
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;
        final package = _birthdayController.selectedPackage;
        final birthdaySubmission = _birthdayController.submission;
        final contactSubmission = _contactController.submission;
        final isBirthdayRequest = _selectedType.isBirthdayRequest;
        final hasSubmission = isBirthdayRequest
            ? birthdaySubmission != null
            : contactSubmission != null;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              hasSubmission
                  ? _selectedType.successTitle
                  : _selectedType.screenTitle,
            ),
          ),
          bottomNavigationBar: hasSubmission
              ? null
              : StarKidsBottomCtaBar(
                  child: StarKidsButton.primary(
                    label: _selectedType.submitButtonLabel,
                    icon: isBirthdayRequest
                        ? Icons.send_rounded
                        : Icons.chat_bubble_rounded,
                    isLoading: _isSubmitting,
                    onPressed:
                        _isSubmitting ? null : () => _submitActiveForm(branch),
                  ),
                ),
          body: StarKidsContentSwitcher(
            child: hasSubmission
                ? isBirthdayRequest
                    ? _RequestSuccessView(
                        key: const ValueKey('birthday-request-success'),
                        branch: branch,
                        selectedPackage: package,
                        type: RequestType.birthdayRequest,
                        submission: birthdaySubmission!,
                        onBackHome: () =>
                            Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.home,
                          (route) => false,
                        ),
                        onCreateAnother: () => _birthdayController.resetForm(
                          preserveSelectedPackage: package != null,
                        ),
                      )
                    : _ContactRequestSuccessView(
                        key: const ValueKey('contact-request-success'),
                        submission: contactSubmission!,
                        contextLabel: _contactContextLabel,
                        onBackHome: () =>
                            Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.home,
                          (route) => false,
                        ),
                        onCreateAnother: _contactController.resetForm,
                      )
                : isBirthdayRequest
                    ? _BirthdayRequestFormView(
                        key: const ValueKey('birthday-request-form'),
                        formKey: _birthdayFormKey,
                        type: RequestType.birthdayRequest,
                        typeSelector: _RequestTypeSelector(
                          selectedType: _selectedType,
                          onSelected: _selectRequestType,
                        ),
                        controller: _birthdayController,
                        branch: branch,
                        selectedPackage: package,
                        onPickBranch: _showBranchPicker,
                        onPickPackage: _showPackagePicker,
                      )
                    : _ContactRequestFormView(
                        key: const ValueKey('contact-request-form'),
                        formKey: _contactFormKey,
                        type: RequestType.contact,
                        typeSelector: _RequestTypeSelector(
                          selectedType: _selectedType,
                          onSelected: _selectRequestType,
                        ),
                        controller: _contactController,
                        contextLabel: _contactContextLabel,
                      ),
          ),
        );
      },
    );
  }

  bool get _isSubmitting => _selectedType.isBirthdayRequest
      ? _birthdayController.isSubmitting
      : _contactController.isSubmitting;

  void _selectRequestType(RequestType type) {
    if (_selectedType == type) {
      return;
    }

    _birthdayController.clearTransientFeedback();
    _contactController.clearTransientFeedback();
    setState(() {
      _selectedType = type;
    });
  }

  Future<void> _submitActiveForm(BranchOption branch) async {
    if (_selectedType.isBirthdayRequest) {
      await _submitBirthdayForm(branch);
      return;
    }

    await _submitContactForm();
  }

  Future<void> _submitBirthdayForm(BranchOption branch) async {
    FocusScope.of(context).unfocus();

    final formIsValid = _birthdayFormKey.currentState?.validate() ?? false;
    final selectionsAreValid = _birthdayController.validateSelections();

    if (!formIsValid || !selectionsAreValid) {
      return;
    }

    await _birthdayController.submit(branchId: branch.id);
  }

  Future<void> _submitContactForm() async {
    FocusScope.of(context).unfocus();

    final formIsValid = _contactFormKey.currentState?.validate() ?? false;
    if (!formIsValid) {
      return;
    }

    await _contactController.submit();
  }

  Future<void> _showBranchPicker() async {
    List<BranchOption> branches;
    try {
      branches = await ServiceRegistry.branchRepository.listBranches();
    } catch (_) {
      if (mounted) {
        _showLoadError('Не удалось загрузить филиалы. Попробуйте позже.');
      }
      return;
    }

    if (branches.isEmpty) {
      _showLoadError('Список филиалов пока недоступен.');
      return;
    }

    if (!mounted) {
      return;
    }

    final selectedBranchId = await showStarKidsModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? StarKidsDarkColors.surfaceElevated
          : StarKidsColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SelectionSheet<BranchOption>(
        title: 'Выберите филиал',
        items: branches,
        currentId: ServiceRegistry.selectedBranchController.selectedBranchId,
        titleBuilder: (branch) => branch.name,
        subtitleBuilder: (branch) => branch.address,
        itemIdBuilder: (branch) => branch.id,
      ),
    );

    if (selectedBranchId == null) {
      return;
    }

    await ServiceRegistry.selectedBranchController.selectBranch(
      selectedBranchId,
    );
  }

  Future<void> _showPackagePicker() async {
    List<BirthdayPackage> packages;
    try {
      packages = await ServiceRegistry.birthdayPackageRepository.listPackages(
        branchId: ServiceRegistry.selectedBranchController.selectedBranchId,
      );
    } catch (_) {
      _showLoadError('Не удалось загрузить пакеты. Попробуйте позже.');
      return;
    }

    if (packages.isEmpty) {
      _showLoadError('Для выбранного филиала пока нет опубликованных пакетов.');
      return;
    }

    if (!mounted) {
      return;
    }

    final selectedPackageId = await showStarKidsModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? StarKidsDarkColors.surfaceElevated
          : StarKidsColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SelectionSheet<BirthdayPackage>(
        title: 'Выберите пакет',
        items: packages,
        currentId: _birthdayController.selectedPackageId,
        titleBuilder: (item) => item.name,
        subtitleBuilder: (item) => '${item.priceLabel} • ${item.guestLabel}',
        itemIdBuilder: (item) => item.id,
      ),
    );

    if (selectedPackageId == null) {
      return;
    }

    final selectedPackage = packages.firstWhere(
      (item) => item.id == selectedPackageId,
    );
    _birthdayController.updateSelectedPackage(
      selectedPackageId,
      selectedPackage: selectedPackage,
    );
  }

  void _showLoadError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RequestTypeSelector extends StatelessWidget {
  const _RequestTypeSelector({
    required this.selectedType,
    required this.onSelected,
  });

  final RequestType selectedType;
  final ValueChanged<RequestType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const StarKidsSectionHeader(
          title: 'Какой запрос нужен',
          description:
              'Можно оставить заявку на праздник или короткий запрос на обратную связь.',
        ),
        const SizedBox(height: StarKidsSpacing.lg),
        ...RequestType.values.map(
          (type) => Padding(
            padding: const EdgeInsets.only(bottom: StarKidsSpacing.md),
            child: _RequestTypeOptionCard(
              type: type,
              isSelected: type == selectedType,
              onTap: () => onSelected(type),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestTypeOptionCard extends StatelessWidget {
  const _RequestTypeOptionCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final RequestType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary;
    return Material(
      color: isDark
          ? StarKidsDarkColors.surfaceElevated
          : StarKidsColors.surfacePrimary,
      borderRadius: BorderRadius.circular(StarKidsRadii.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(StarKidsSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StarKidsRadii.xl),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark
                      ? StarKidsDarkColors.borderDefault
                      : StarKidsColors.borderDefault),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? StarKidsDarkColors.glassSurface
                      : StarKidsColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(StarKidsRadii.lg),
                ),
                child: Icon(
                  type.isBirthdayRequest
                      ? Icons.cake_rounded
                      : Icons.support_agent_rounded,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: StarKidsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: textTheme.titleMedium),
                    const SizedBox(height: StarKidsSpacing.xs),
                    Text(type.selectorDescription, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthdayRequestFormView extends StatelessWidget {
  const _BirthdayRequestFormView({
    super.key,
    required this.formKey,
    required this.typeSelector,
    required this.type,
    required this.controller,
    required this.branch,
    required this.selectedPackage,
    required this.onPickBranch,
    required this.onPickPackage,
  });

  final GlobalKey<FormState> formKey;
  final Widget typeSelector;
  final RequestType type;
  final BirthdayRequestFormController controller;
  final BranchOption branch;
  final BirthdayPackage? selectedPackage;
  final VoidCallback onPickBranch;
  final VoidCallback onPickPackage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            StarKidsSpacing.xl,
            StarKidsSpacing.lg,
            StarKidsSpacing.xl,
            StarKidsSpacing.x5l,
          ),
          children: [
            typeSelector,
            const SizedBox(height: StarKidsSpacing.xl),
            StarKidsSectionHeader(
              title: type.formTitle,
              description: type.formDescription,
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            Container(
              padding: const EdgeInsets.all(StarKidsSpacing.lg),
              decoration: BoxDecoration(
                color: isDark
                    ? StarKidsDarkColors.surfaceElevated
                    : StarKidsColors.surfacePrimary,
                borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                border: Border.all(
                  color: isDark
                      ? StarKidsDarkColors.borderDefault
                      : StarKidsColors.borderDefault,
                ),
              ),
              child: Column(
                children: [
                  StarKidsSelectField(
                    label: 'Филиал',
                    value: branch.name,
                    helperText: branch.address,
                    leadingIcon: Icons.location_on_rounded,
                    onTap: onPickBranch,
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  StarKidsSelectField(
                    label: 'Пакет праздника',
                    value: selectedPackage?.name,
                    placeholderText: 'Выберите пакет',
                    helperText: selectedPackage == null
                        ? 'Выберите подходящий пакет для заявки.'
                        : '${selectedPackage!.priceLabel} • ${selectedPackage!.guestLabel}',
                    errorText: controller.packageErrorText,
                    leadingIcon: Icons.cake_rounded,
                    onTap: onPickPackage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: StarKidsSpacing.x2l),
            if (controller.submissionErrorText != null) ...[
              _RequestStatusBanner(
                title: 'Заявка пока не отправлена',
                description: controller.submissionErrorText!,
                backgroundColor: isDark
                    ? StarKidsDarkColors.statusErrorSurface
                    : StarKidsColors.statusErrorSurface,
                foregroundColor: isDark
                    ? StarKidsDarkColors.statusError
                    : StarKidsColors.statusError,
                icon: Icons.error_rounded,
              ),
              const SizedBox(height: StarKidsSpacing.lg),
            ],
            StarKidsInputField(
              controller: controller.nameController,
              label: 'Имя родителя',
              hintText: 'Например, Айдана',
              prefixIcon: Icons.person_rounded,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: controller.validateName,
              onChanged: (_) => controller.clearTransientFeedback(),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsInputField(
              controller: controller.phoneController,
              label: 'Телефон',
              hintText: '+7 707 000 00 00',
              prefixIcon: Icons.call_rounded,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: controller.validatePhone,
              inputFormatters: [KzPhoneInputFormatter()],
              onChanged: (_) => controller.clearTransientFeedback(),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsSelectField(
              label: 'Желаемая дата',
              value: controller.desiredDate == null
                  ? null
                  : controller.formatDate(controller.desiredDate),
              placeholderText: 'Выберите дату',
              helperText: 'Выберите удобную дату праздника.',
              leadingIcon: Icons.calendar_month_rounded,
              onTap: () => controller.pickDesiredDate(context),
              errorText: controller.dateErrorText,
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsInputField(
              controller: controller.guestCountController,
              label: 'Количество гостей',
              hintText: 'Например, 12',
              prefixIcon: Icons.groups_rounded,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: controller.validateGuestCount,
              onChanged: (_) => controller.clearTransientFeedback(),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsInputField(
              controller: controller.commentController,
              label: 'Комментарий',
              hintText: 'Торт, аниматор, любимые герои, время начала',
              helperText:
                  'Необязательно. Напишите пожелания, чтобы менеджер подготовил подходящий сценарий.',
              maxLines: 4,
              minLines: 4,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => controller.clearTransientFeedback(),
            ),
            const SizedBox(height: StarKidsSpacing.xl),
            Text(
              'После отправки менеджер свяжется с вами, подтвердит дату и подскажет по пакету.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRequestFormView extends StatelessWidget {
  const _ContactRequestFormView({
    super.key,
    required this.formKey,
    required this.typeSelector,
    required this.type,
    required this.controller,
    this.contextLabel,
  });

  final GlobalKey<FormState> formKey;
  final Widget typeSelector;
  final RequestType type;
  final ContactRequestFormController controller;
  final String? contextLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            StarKidsSpacing.xl,
            StarKidsSpacing.lg,
            StarKidsSpacing.xl,
            StarKidsSpacing.x5l,
          ),
          children: [
            typeSelector,
            const SizedBox(height: StarKidsSpacing.xl),
            StarKidsSectionHeader(
              title: type.formTitle,
              description: type.formDescription,
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            if (contextLabel != null) ...[
              _RequestContextCard(
                label: contextLabel!,
                description: controller.hasInitialMessage
                    ? 'Контекст по выбранному филиалу уже добавлен в текст запроса. Можно оставить как есть или отредактировать.'
                    : 'Контекст по выбранному филиалу сохранится в запросе для менеджера.',
              ),
              const SizedBox(height: StarKidsSpacing.lg),
            ],
            if (controller.submissionErrorText != null) ...[
              _RequestStatusBanner(
                title: 'Запрос пока не отправлен',
                description: controller.submissionErrorText!,
                backgroundColor: isDark
                    ? StarKidsDarkColors.statusErrorSurface
                    : StarKidsColors.statusErrorSurface,
                foregroundColor: isDark
                    ? StarKidsDarkColors.statusError
                    : StarKidsColors.statusError,
                icon: Icons.error_rounded,
              ),
              const SizedBox(height: StarKidsSpacing.lg),
            ],
            StarKidsInputField(
              controller: controller.nameController,
              label: 'Имя родителя',
              hintText: 'Например, Айдана',
              prefixIcon: Icons.person_rounded,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: controller.validateName,
              onChanged: (_) => controller.clearTransientFeedback(),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsInputField(
              controller: controller.phoneController,
              label: 'Телефон',
              hintText: '+7 707 000 00 00',
              prefixIcon: Icons.call_rounded,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: controller.validatePhone,
              inputFormatters: [KzPhoneInputFormatter()],
              onChanged: (_) => controller.clearTransientFeedback(),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsInputField(
              controller: controller.emailController,
              label: 'Email',
              hintText: 'Например, family@example.com',
              helperText:
                  'Необязательно. Если удобно, продублируем детали на почту.',
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: controller.validateEmail,
              onChanged: (_) => controller.clearTransientFeedback(),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsInputField(
              controller: controller.messageController,
              label: 'Что нужно уточнить',
              hintText:
                  'Свободные даты, формат праздника, цены или другой вопрос',
              helperText: controller.hasInitialMessage
                  ? 'Мы уже добавили стартовый контекст по выбранному филиалу. При желании уточните вопрос своими словами.'
                  : 'Необязательно. Чем точнее вопрос, тем быстрее менеджер подготовит ответ.',
              maxLines: 4,
              minLines: 4,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => controller.clearTransientFeedback(),
            ),
            const SizedBox(height: StarKidsSpacing.xl),
            Text(
              'После отправки менеджер перезвонит и поможет выбрать подходящий сценарий без лишних шагов.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestSuccessView extends StatelessWidget {
  const _RequestSuccessView({
    super.key,
    required this.branch,
    required this.selectedPackage,
    required this.type,
    required this.submission,
    required this.onBackHome,
    required this.onCreateAnother,
  });

  final BranchOption branch;
  final BirthdayPackage? selectedPackage;
  final RequestType type;
  final BirthdayRequestSubmission submission;
  final VoidCallback onBackHome;
  final VoidCallback onCreateAnother;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(StarKidsSpacing.xl),
        children: [
          _RequestStatusBanner(
            title: type.successTitle,
            description: type.successDescription,
            backgroundColor: isDark
                ? StarKidsDarkColors.statusSuccessSurface
                : StarKidsColors.statusSuccessSurface,
            foregroundColor: isDark
                ? StarKidsDarkColors.statusSuccess
                : StarKidsColors.statusSuccess,
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: StarKidsSpacing.x2l),
          Container(
            padding: const EdgeInsets.all(StarKidsSpacing.lg),
            decoration: BoxDecoration(
              color: isDark
                  ? StarKidsDarkColors.surfaceElevated
                  : StarKidsColors.surfacePrimary,
              borderRadius: BorderRadius.circular(StarKidsRadii.xl),
              border: Border.all(
                color: isDark
                    ? StarKidsDarkColors.borderDefault
                    : StarKidsColors.borderDefault,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SuccessRow(label: 'Филиал', value: branch.name),
                const SizedBox(height: StarKidsSpacing.md),
                _SuccessRow(
                  label: 'Пакет',
                  value: selectedPackage?.name ?? 'Менеджер поможет подобрать',
                ),
                const SizedBox(height: StarKidsSpacing.md),
                _SuccessRow(label: 'Номер заявки', value: submission.requestId),
                const SizedBox(height: StarKidsSpacing.md),
                _SuccessRow(label: 'Следующий шаг', value: submission.nextStep),
              ],
            ),
          ),
          const SizedBox(height: StarKidsSpacing.x2l),
          StarKidsButton.primary(
            label: 'На главную',
            icon: Icons.home_rounded,
            onPressed: onBackHome,
          ),
          const SizedBox(height: StarKidsSpacing.sm),
          Center(
            child: StarKidsButton.ghost(
              label: selectedPackage == null
                  ? type.createAnotherLabel
                  : 'Оставить еще одну заявку по этому пакету',
              onPressed: onCreateAnother,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRequestSuccessView extends StatelessWidget {
  const _ContactRequestSuccessView({
    super.key,
    required this.submission,
    this.contextLabel,
    required this.onBackHome,
    required this.onCreateAnother,
  });

  final ContactRequestSubmission submission;
  final String? contextLabel;
  final VoidCallback onBackHome;
  final VoidCallback onCreateAnother;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(StarKidsSpacing.xl),
        children: [
          _RequestStatusBanner(
            title: submission.type.successTitle,
            description: submission.type.successDescription,
            backgroundColor: isDark
                ? StarKidsDarkColors.statusSuccessSurface
                : StarKidsColors.statusSuccessSurface,
            foregroundColor: isDark
                ? StarKidsDarkColors.statusSuccess
                : StarKidsColors.statusSuccess,
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: StarKidsSpacing.x2l),
          Container(
            padding: const EdgeInsets.all(StarKidsSpacing.lg),
            decoration: BoxDecoration(
              color: isDark
                  ? StarKidsDarkColors.surfaceElevated
                  : StarKidsColors.surfacePrimary,
              borderRadius: BorderRadius.circular(StarKidsRadii.xl),
              border: Border.all(
                color: isDark
                    ? StarKidsDarkColors.borderDefault
                    : StarKidsColors.borderDefault,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SuccessRow(
                  label: 'Тип обращения',
                  value: submission.type.label,
                ),
                if (contextLabel != null) ...[
                  const SizedBox(height: StarKidsSpacing.md),
                  _SuccessRow(label: 'Контекст', value: contextLabel!),
                ],
                const SizedBox(height: StarKidsSpacing.md),
                _SuccessRow(label: 'Номер заявки', value: submission.requestId),
                const SizedBox(height: StarKidsSpacing.md),
                _SuccessRow(label: 'Статус', value: submission.status.label),
                const SizedBox(height: StarKidsSpacing.md),
                const _SuccessRow(
                  label: 'Следующий шаг',
                  value:
                      'Менеджер свяжется с вами и поможет с вопросом по филиалу или формату праздника.',
                ),
              ],
            ),
          ),
          const SizedBox(height: StarKidsSpacing.x2l),
          StarKidsButton.primary(
            label: 'На главную',
            icon: Icons.home_rounded,
            onPressed: onBackHome,
          ),
          const SizedBox(height: StarKidsSpacing.sm),
          Center(
            child: StarKidsButton.ghost(
              label: submission.type.createAnotherLabel,
              onPressed: onCreateAnother,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestContextCard extends StatelessWidget {
  const _RequestContextCard({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.glassSurface
            : StarKidsColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : StarKidsColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.titleMedium?.copyWith(
              color: isDark
                  ? StarKidsDarkColors.accentPink
                  : StarKidsColors.brandPrimary,
            ),
          ),
          const SizedBox(height: StarKidsSpacing.xs),
          Text(description, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SelectionSheet<T> extends StatelessWidget {
  const _SelectionSheet({
    required this.title,
    required this.items,
    required this.currentId,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.itemIdBuilder,
  });

  final String title;
  final List<T> items;
  final String? currentId;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final String Function(T item) itemIdBuilder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(StarKidsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.headlineSmall),
            const SizedBox(height: StarKidsSpacing.lg),
            ...items.map((item) {
              final itemId = itemIdBuilder(item);
              final isCurrent = itemId == currentId;

              return Padding(
                padding: const EdgeInsets.only(bottom: StarKidsSpacing.sm),
                child: Material(
                  color: isDark
                      ? StarKidsDarkColors.surfacePrimary
                      : StarKidsColors.surfacePrimary,
                  borderRadius: BorderRadius.circular(StarKidsRadii.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(StarKidsRadii.lg),
                    onTap: () => Navigator.of(context).pop(itemId),
                    child: Container(
                      padding: const EdgeInsets.all(StarKidsSpacing.lg),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
                        border: Border.all(
                          color: isCurrent
                              ? accentColor
                              : (isDark
                                  ? StarKidsDarkColors.borderDefault
                                  : StarKidsColors.borderDefault),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titleBuilder(item),
                                  style: textTheme.titleLarge,
                                ),
                                const SizedBox(height: StarKidsSpacing.xs),
                                Text(
                                  subtitleBuilder(item),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? StarKidsDarkColors.textSecondary
                                        : StarKidsColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: StarKidsSpacing.md),
                          Icon(
                            isCurrent
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            color: isCurrent
                                ? accentColor
                                : (isDark
                                    ? StarKidsDarkColors.textSecondary
                                    : StarKidsColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RequestStatusBanner extends StatelessWidget {
  const _RequestStatusBanner({
    required this.title,
    required this.description,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  final String title;
  final String description;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: StarKidsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(color: foregroundColor),
                ),
                const SizedBox(height: StarKidsSpacing.xs),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? StarKidsDarkColors.textPrimary
                        : StarKidsColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  const _SuccessRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        const SizedBox(height: StarKidsSpacing.xs),
        Text(value, style: textTheme.bodyLarge),
      ],
    );
  }
}
