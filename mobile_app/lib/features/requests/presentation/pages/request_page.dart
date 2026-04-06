import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_input_field.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/design_system/widgets/star_kids_select_field.dart';
import '../../../birthdays/data/birthday_package_seed_data.dart';
import '../../../birthdays/domain/birthday_package.dart';
import '../../../branches/data/branch_seed_data.dart';
import '../../../branches/domain/branch_option.dart';
import '../controllers/birthday_request_form_controller.dart';
import '../../domain/birthday_request_submission.dart';
import '../formatters/kz_phone_input_formatter.dart';
import '../models/request_page_args.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({
    super.key,
    this.args,
  });

  final RequestPageArgs? args;

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  final _formKey = GlobalKey<FormState>();
  late final BirthdayRequestFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BirthdayRequestFormController(
      repository: ServiceRegistry.birthdayRequestRepository,
      initialPackageId: widget.args?.initialPackageId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _controller,
        ServiceRegistry.selectedBranchController,
      ]),
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;
        final package = _controller.selectedPackage;
        final submission = _controller.submission;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              submission == null ? 'Заявка на день рождения' : 'Заявка отправлена',
            ),
          ),
          bottomNavigationBar: submission == null
              ? StarKidsBottomCtaBar(
                  child: StarKidsButton.primary(
                    label: 'Отправить заявку',
                    icon: Icons.send_rounded,
                    isLoading: _controller.isSubmitting,
                    onPressed: _controller.isSubmitting
                        ? null
                        : () => _submitForm(branch),
                  ),
                )
              : null,
          body: submission == null
              ? _RequestFormView(
                  formKey: _formKey,
                  controller: _controller,
                  branch: branch,
                  selectedPackage: package,
                  onPickBranch: _showBranchPicker,
                  onPickPackage: _showPackagePicker,
                )
              : _RequestSuccessView(
                  branch: branch,
                  selectedPackage: package,
                  submission: submission,
                  onBackHome: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home,
                    (route) => false,
                  ),
                  onCreateAnother: _controller.resetForm,
                ),
        );
      },
    );
  }

  Future<void> _submitForm(BranchOption branch) async {
    FocusScope.of(context).unfocus();

    final formIsValid = _formKey.currentState?.validate() ?? false;
    final selectionsAreValid = _controller.validateSelections();

    if (!formIsValid || !selectionsAreValid) {
      return;
    }

    await _controller.submit(branchId: branch.id);
  }

  Future<void> _showBranchPicker() async {
    final selectedBranchId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: StarKidsColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SelectionSheet<BranchOption>(
        title: 'Выберите филиал',
        items: branchSeedData,
        currentId: ServiceRegistry.selectedBranchController.selectedBranchId,
        titleBuilder: (branch) => branch.name,
        subtitleBuilder: (branch) => branch.address,
        itemIdBuilder: (branch) => branch.id,
      ),
    );

    if (selectedBranchId == null) {
      return;
    }

    await ServiceRegistry.selectedBranchController.selectBranch(selectedBranchId);
  }

  Future<void> _showPackagePicker() async {
    final selectedPackageId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: StarKidsColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SelectionSheet<BirthdayPackage>(
        title: 'Выберите пакет',
        items: birthdayPackageSeedData,
        currentId: _controller.selectedPackageId,
        titleBuilder: (item) => item.name,
        subtitleBuilder: (item) => '${item.priceLabel} • ${item.guestLabel}',
        itemIdBuilder: (item) => item.id,
      ),
    );

    if (selectedPackageId == null) {
      return;
    }

    _controller.updateSelectedPackage(selectedPackageId);
  }
}

class _RequestFormView extends StatelessWidget {
  const _RequestFormView({
    required this.formKey,
    required this.controller,
    required this.branch,
    required this.selectedPackage,
    required this.onPickBranch,
    required this.onPickPackage,
  });

  final GlobalKey<FormState> formKey;
  final BirthdayRequestFormController controller;
  final BranchOption branch;
  final BirthdayPackage? selectedPackage;
  final VoidCallback onPickBranch;
  final VoidCallback onPickPackage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
            const StarKidsSectionHeader(
              title: 'Оставьте заявку за пару минут',
              description:
                  'Филиал и пакет уже под рукой. Осталось указать контакт и удобную дату.',
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            Container(
              padding: const EdgeInsets.all(StarKidsSpacing.lg),
              decoration: BoxDecoration(
                color: StarKidsColors.surfacePrimary,
                borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                border: Border.all(color: StarKidsColors.borderDefault),
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
                backgroundColor: StarKidsColors.statusErrorSurface,
                foregroundColor: StarKidsColors.statusError,
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

class _RequestSuccessView extends StatelessWidget {
  const _RequestSuccessView({
    required this.branch,
    required this.selectedPackage,
    required this.submission,
    required this.onBackHome,
    required this.onCreateAnother,
  });

  final BranchOption branch;
  final BirthdayPackage? selectedPackage;
  final BirthdayRequestSubmission submission;
  final VoidCallback onBackHome;
  final VoidCallback onCreateAnother;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(StarKidsSpacing.xl),
        children: [
          const _RequestStatusBanner(
            title: 'Заявка отправлена',
            description:
                'Мы зафиксировали ваш интерес и передадим запрос менеджеру Star Kids.',
            backgroundColor: StarKidsColors.statusSuccessSurface,
            foregroundColor: StarKidsColors.statusSuccess,
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: StarKidsSpacing.x2l),
          Container(
            padding: const EdgeInsets.all(StarKidsSpacing.lg),
            decoration: BoxDecoration(
              color: StarKidsColors.surfacePrimary,
              borderRadius: BorderRadius.circular(StarKidsRadii.xl),
              border: Border.all(color: StarKidsColors.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SuccessRow(
                  label: 'Филиал',
                  value: branch.name,
                ),
                const SizedBox(height: StarKidsSpacing.md),
                _SuccessRow(
                  label: 'Пакет',
                  value: selectedPackage?.name ?? 'Менеджер поможет подобрать',
                ),
                const SizedBox(height: StarKidsSpacing.md),
                _SuccessRow(
                  label: 'Номер заявки',
                  value: submission.requestId,
                ),
                const SizedBox(height: StarKidsSpacing.md),
                _SuccessRow(
                  label: 'Следующий шаг',
                  value: submission.nextStep,
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
              label: 'Оставить еще одну заявку',
              onPressed: onCreateAnother,
            ),
          ),
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
                  color: StarKidsColors.surfacePrimary,
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
                              ? StarKidsColors.brandPrimary
                              : StarKidsColors.borderDefault,
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
                                  style: textTheme.bodyMedium,
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
                                ? StarKidsColors.brandPrimary
                                : StarKidsColors.textSecondary,
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
                    color: StarKidsColors.textPrimary,
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
  const _SuccessRow({
    required this.label,
    required this.value,
  });

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
