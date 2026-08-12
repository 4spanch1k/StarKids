import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/router/nested_navigation.dart';
import '../../../../core/design_system/foundations/sk_tokens.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_bottom_sheet.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/sk_date_pill_row.dart';
import '../../../../core/design_system/widgets/sk_guest_stepper.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
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
          appBar: GlassAppBar(
            leading: const NestedBackButton(),
            title: Text(
              hasSubmission
                  ? _selectedType.successTitle
                  : _selectedType.screenTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          bottomNavigationBar: hasSubmission
              ? null
              : StarKidsBottomCtaBar(
                  child: PrimaryButton(
                    label: _selectedType.submitButtonLabel,
                    icon: isBirthdayRequest
                        ? Icons.send_rounded
                        : Icons.chat_bubble_rounded,
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

    final selectedBranchId = await showGlassBottomSheet<String>(
      context: context,
      title: 'Выберите филиал',
      builder: (context, _) => _SelectionSheet<BranchOption>(
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

    final selectedPackageId = await showGlassBottomSheet<String>(
      context: context,
      title: 'Выберите пакет',
      builder: (context, _) => _SelectionSheet<BirthdayPackage>(
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
        const SizedBox(height: SKSpacing.x4),
        ...RequestType.values.map(
          (type) => Padding(
            padding: const EdgeInsets.only(bottom: SKSpacing.x3),
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
    final c = SKTheme.of(context).colors;

    return Material(
      color: c.elevated,
      borderRadius: BorderRadius.circular(SKRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(SKRadius.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(SKSpacing.x4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SKRadius.xl),
            border: Border.all(
              color: isSelected ? c.cta : c.hairline,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.elevated,
                  borderRadius: BorderRadius.circular(SKRadius.lg),
                  border: Border.all(color: c.hairline, width: 0.5),
                ),
                child: Icon(
                  type.isBirthdayRequest
                      ? Icons.cake_rounded
                      : Icons.support_agent_rounded,
                  color: c.cta,
                ),
              ),
              const SizedBox(width: SKSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: textTheme.titleMedium),
                    const SizedBox(height: SKSpacing.x1),
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
    final c = SKTheme.of(context).colors;

    return SafeArea(
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SKSpacing.x5,
            SKSpacing.x4,
            SKSpacing.x5,
            SKSpacing.x12,
          ),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: SKSpacing.x5),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Соберём праздник\nза '),
                    TextSpan(
                      text: 'пару минут.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 34,
                  height: 1.05,
                  letterSpacing: -0.85,
                  color: SK.ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(SKSpacing.x4),
              decoration: BoxDecoration(
                color: c.elevated,
                borderRadius: BorderRadius.circular(SKRadius.xl),
                border: Border.all(color: c.hairline, width: 0.5),
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
                  const SizedBox(height: SKSpacing.x4),
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
            const SizedBox(height: SKSpacing.x6),
            if (controller.submissionErrorText != null) ...[
              _RequestStatusBanner(
                title: 'Заявка пока не отправлена',
                description: controller.submissionErrorText!,
                backgroundColor: c.dangerSoft,
                foregroundColor: c.danger,
                icon: Icons.error_rounded,
              ),
              const SizedBox(height: SKSpacing.x4),
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
            const SizedBox(height: SKSpacing.x4),
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
            const SizedBox(height: SKSpacing.x4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ближайшие даты', style: textTheme.labelMedium),
                const SizedBox(height: SKSpacing.x2),
                SkDatePillRow(
                  selectedDate: controller.desiredDate,
                  onDateSelected: (date) {
                    controller.updateDesiredDate(date);
                  },
                  daysAhead: 30,
                ),
              ],
            ),
            const SizedBox(height: SKSpacing.x3),
            StarKidsSelectField(
              label: 'Или выберите другую дату',
              value: controller.desiredDate == null
                  ? null
                  : controller.formatDate(controller.desiredDate),
              placeholderText: 'Выберите дату',
              helperText: 'Выберите удобную дату праздника.',
              leadingIcon: Icons.calendar_month_rounded,
              onTap: () => controller.pickDesiredDate(context),
              errorText: controller.dateErrorText,
            ),
            const SizedBox(height: SKSpacing.x4),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final guests =
                    int.tryParse(controller.guestCountController.text) ?? 10;
                return SkGuestStepper(
                  value: guests.clamp(1, 30),
                  onChanged: (newVal) {
                    controller.guestCountController.text = newVal.toString();
                    controller.clearTransientFeedback();
                  },
                );
              },
            ),
            const SizedBox(height: SKSpacing.x4),
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
            const SizedBox(height: SKSpacing.x5),
            Text(
              'Запрос уйдёт менеджеру по филиалу Al-Farabi.',
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
    final c = SKTheme.of(context).colors;

    return SafeArea(
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SKSpacing.x5,
            SKSpacing.x4,
            SKSpacing.x5,
            SKSpacing.x12,
          ),
          children: [
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Короткий запрос\n'),
                  TextSpan(
                    text: 'без переписок.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 34,
                height: 1.05,
                letterSpacing: -0.85,
                color: SK.ink,
              ),
            ),
            const SizedBox(height: SKSpacing.x2),
            const Text(
              'Опишите вопрос — перезвоним и поможем без лишних уточнений.',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 15,
                height: 1.45,
                color: SK.ink3,
              ),
            ),
            const SizedBox(height: SKSpacing.x4),
            if (contextLabel != null) ...[
              _RequestContextCard(
                label: contextLabel!,
                description: 'Запрос уйдёт менеджеру по выбранному филиалу.',
              ),
              const SizedBox(height: SKSpacing.x4),
            ],
            if (controller.submissionErrorText != null) ...[
              _RequestStatusBanner(
                title: 'Запрос пока не отправлен',
                description: controller.submissionErrorText!,
                backgroundColor: c.dangerSoft,
                foregroundColor: c.danger,
                icon: Icons.error_rounded,
              ),
              const SizedBox(height: SKSpacing.x4),
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
            const SizedBox(height: SKSpacing.x4),
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
            const SizedBox(height: SKSpacing.x4),
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
            const SizedBox(height: SKSpacing.x4),
            StarKidsInputField(
              controller: controller.messageController,
              label: 'Что нужно уточнить',
              hintText: 'Например: свободные даты на 12 мая',
              helperText: null,
              maxLines: 4,
              minLines: 4,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => controller.clearTransientFeedback(),
            ),
            const SizedBox(height: SKSpacing.x5),
            Text(
              'Запрос уйдёт менеджеру по филиалу Al-Farabi.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestSuccessView extends StatefulWidget {
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
  State<_RequestSuccessView> createState() => _RequestSuccessViewState();
}

class _RequestSuccessViewState extends State<_RequestSuccessView> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onBackHome();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Stack(
      children: [
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(SKSpacing.x5),
            children: [
              _RequestStatusBanner(
                title: widget.type.successTitle,
                description: widget.type.successDescription,
                backgroundColor: c.successSoft,
                foregroundColor: c.success,
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(height: SKSpacing.x6),
              Container(
                padding: const EdgeInsets.all(SKSpacing.x4),
                decoration: BoxDecoration(
                  color: c.elevated,
                  borderRadius: BorderRadius.circular(SKRadius.xl),
                  border: Border.all(color: c.hairline, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SuccessRow(label: 'Филиал', value: widget.branch.name),
                    const SizedBox(height: SKSpacing.x3),
                    _SuccessRow(
                      label: 'Пакет',
                      value: widget.selectedPackage?.name ??
                          'Менеджер поможет подобрать',
                    ),
                    const SizedBox(height: SKSpacing.x3),
                    _SuccessRow(
                        label: 'Номер заявки',
                        value: widget.submission.requestId),
                    const SizedBox(height: SKSpacing.x3),
                    _SuccessRow(
                        label: 'Следующий шаг',
                        value: widget.submission.nextStep),
                  ],
                ),
              ),
              const SizedBox(height: SKSpacing.x6),
              PrimaryButton(
                label: 'На главную',
                icon: Icons.home_rounded,
                onPressed: widget.onBackHome,
              ),
              const SizedBox(height: SKSpacing.x2),
              Center(
                child: TextButton(
                  onPressed: widget.onCreateAnother,
                  child: Text(
                    widget.selectedPackage == null
                        ? widget.type.createAnotherLabel
                        : 'Оставить еще одну заявку по этому пакету',
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            colors: const [
              Color(0xFFFF5A5F),
              Color(0xFFFFC857),
              Color(0xFFB6E3C8),
              Color(0xFFE5D4F2),
              Color(0xFF2B1F1A),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactRequestSuccessView extends StatefulWidget {
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
  State<_ContactRequestSuccessView> createState() =>
      _ContactRequestSuccessViewState();
}

class _ContactRequestSuccessViewState
    extends State<_ContactRequestSuccessView> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onBackHome();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Stack(
      children: [
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(SKSpacing.x5),
            children: [
              _RequestStatusBanner(
                title: widget.submission.type.successTitle,
                description: widget.submission.type.successDescription,
                backgroundColor: c.successSoft,
                foregroundColor: c.success,
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(height: SKSpacing.x6),
              Container(
                padding: const EdgeInsets.all(SKSpacing.x4),
                decoration: BoxDecoration(
                  color: c.elevated,
                  borderRadius: BorderRadius.circular(SKRadius.xl),
                  border: Border.all(color: c.hairline, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SuccessRow(
                      label: 'Тип обращения',
                      value: widget.submission.type.label,
                    ),
                    if (widget.contextLabel != null) ...[
                      const SizedBox(height: SKSpacing.x3),
                      _SuccessRow(
                          label: 'Контекст', value: widget.contextLabel!),
                    ],
                    const SizedBox(height: SKSpacing.x3),
                    _SuccessRow(
                        label: 'Номер заявки',
                        value: widget.submission.requestId),
                    const SizedBox(height: SKSpacing.x3),
                    _SuccessRow(
                        label: 'Статус', value: widget.submission.status.label),
                    const SizedBox(height: SKSpacing.x3),
                    const _SuccessRow(
                      label: 'Следующий шаг',
                      value:
                          'Менеджер свяжется с вами и поможет с вопросом по филиалу или формату праздника.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SKSpacing.x6),
              PrimaryButton(
                label: 'На главную',
                icon: Icons.home_rounded,
                onPressed: widget.onBackHome,
              ),
              const SizedBox(height: SKSpacing.x2),
              Center(
                child: TextButton(
                  onPressed: widget.onCreateAnother,
                  child: Text(widget.submission.type.createAnotherLabel),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            colors: const [
              Color(0xFFFF5A5F),
              Color(0xFFFFC857),
              Color(0xFFB6E3C8),
              Color(0xFFE5D4F2),
              Color(0xFF2B1F1A),
            ],
          ),
        ),
      ],
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
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x4),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.xl),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.titleMedium?.copyWith(color: c.cta),
          ),
          const SizedBox(height: SKSpacing.x1),
          Text(description, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SelectionSheet<T> extends StatelessWidget {
  const _SelectionSheet({
    required this.items,
    required this.currentId,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.itemIdBuilder,
  });

  final List<T> items;
  final String? currentId;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final String Function(T item) itemIdBuilder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SKSpacing.x5,
        0,
        SKSpacing.x5,
        SKSpacing.x5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          final itemId = itemIdBuilder(item);
          final isCurrent = itemId == currentId;

          return Padding(
            padding: const EdgeInsets.only(bottom: SKSpacing.x2),
            child: Material(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(SKRadius.lg),
                onTap: () => Navigator.of(context).pop(itemId),
                child: Container(
                  padding: const EdgeInsets.all(SKSpacing.x4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SKRadius.lg),
                    border: Border.all(
                      color: isCurrent ? c.cta : c.hairline,
                      width: isCurrent ? 1.5 : 0.5,
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
                            const SizedBox(height: SKSpacing.x1),
                            Text(
                              subtitleBuilder(item),
                              style: textTheme.bodyMedium?.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SKSpacing.x3),
                      Icon(
                        isCurrent
                            ? Icons.check_circle_rounded
                            : Icons.chevron_right_rounded,
                        color: isCurrent ? c.cta : c.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(SKRadius.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: SKSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(color: foregroundColor),
                ),
                const SizedBox(height: SKSpacing.x1),
                Text(
                  description,
                  style: textTheme.bodyMedium,
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
        const SizedBox(height: SKSpacing.x1),
        Text(value, style: textTheme.bodyLarge),
      ],
    );
  }
}
