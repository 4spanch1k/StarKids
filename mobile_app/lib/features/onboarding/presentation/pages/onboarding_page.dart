import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/config/app_environment.dart';
import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../children/domain/child.dart';
import '../../domain/onboarding_repository.dart';
import '../controllers/onboarding_controller.dart';

/// Short, parent-focused family setup shown after authentication for accounts
/// that have not completed onboarding yet.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.controller});

  final OnboardingController? controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _consentVersion = AppEnvironment.privacyConsentVersion;

  late final OnboardingController _controller;
  final _parentNameController = TextEditingController();
  final List<_ChildFormState> _children = [];
  int _step = 0;
  bool _consentAccepted = false;
  String? _error;

  // High-level progress stays fixed even when the family has several
  // children: Welcome → Profile → Family → Consent.
  static const _finalStep = 3;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ServiceRegistry.onboardingController;
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _parentNameController.dispose();
    for (final child in _children) {
      child.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _back() {
    if (_step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _step--;
      _error = null;
    });
  }

  void _next() {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_parentNameController.text.trim().isEmpty) {
        setState(() => _error = 'Введите ваше имя.');
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      setState(() => _step = _finalStep);
      return;
    }
    _submit();
  }

  Future<void> _addChild() async {
    final result = await _showChildEditor();
    if (result == null || !mounted) return;
    setState(() {
      _children.add(result.toFormState());
      _error = null;
    });
  }

  Future<void> _editChild(int index) async {
    final result = await _showChildEditor(initial: _children[index]);
    if (result == null || !mounted) return;
    final old = _children[index];
    final updated = result.toFormState();
    setState(() {
      _children[index] = updated;
      _error = null;
    });
    old.dispose();
  }

  void _removeChild(int index) {
    final removed = _children.removeAt(index);
    removed.dispose();
    setState(() => _error = null);
  }

  Future<_ChildDraftResult?> _showChildEditor({_ChildFormState? initial}) {
    return showDialog<_ChildDraftResult>(
      context: context,
      builder: (context) => _ChildEditorDialog(initial: initial),
    );
  }

  Future<void> _submit() async {
    if (!_consentAccepted) {
      setState(() => _error = 'Подтвердите согласие, чтобы продолжить.');
      return;
    }

    final drafts = [
      for (final child in _children)
        OnboardingChildDraft(
          name: child.name.text.trim(),
          birthDate: child.birthDate!,
          gender: child.gender,
        ),
    ];

    final success = await _controller.complete(
      firstName: _parentNameController.text.trim(),
      children: drafts,
      privacyConsentVersion: _consentVersion,
    );
    if (!mounted) return;
    if (success) {
      // The completion response contains the exact profile and children just
      // persisted. Hydrate shared controllers before Home/Profile can render
      // an empty or stale state while their normal refresh is in flight.
      final completion = _controller.completion;
      if (completion != null &&
          identical(_controller, ServiceRegistry.onboardingController)) {
        ServiceRegistry.profileController.hydrate(completion.profile);
        ServiceRegistry.childrenController.hydrate(completion.children);
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } else {
      setState(
        () => _error = _controller.errorMessage ??
            'Не удалось сохранить профиль. Попробуйте ещё раз.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitting = _controller.isSubmitting;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (_, __) {
        if (!isSubmitting) _back();
      },
      child: Scaffold(
        appBar: _step == 0
            ? null
            : AppBar(
                leading: IconButton(
                  onPressed: isSubmitting ? null : _back,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Назад',
                ),
                title: Text(
                  'Настройка профиля',
                  style: theme.textTheme.titleMedium,
                ),
              ),
        body: SafeArea(
          child: Column(
            children: [
              if (_step > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SKSpacing.x6),
                  child: LinearProgressIndicator(
                    value: (_step / _finalStep).clamp(0.0, 1.0),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(SKRadius.pill),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    SKSpacing.x6,
                    SKSpacing.x6,
                    SKSpacing.x6,
                    SKSpacing.x8,
                  ),
                  child: _buildStep(context),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SKSpacing.x6),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SKSpacing.x6,
                  SKSpacing.x3,
                  SKSpacing.x6,
                  SKSpacing.x6,
                ),
                child: PrimaryButton(
                  label: _step == 0
                      ? 'Продолжить'
                      : _step == _finalStep
                          ? 'Сохранить и продолжить'
                          : 'Далее',
                  onPressed: isSubmitting ? null : _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _welcome(context);
      case 1:
        return _parent(context);
      case 2:
        return _family(context);
      default:
        return _consent(context);
    }
  }

  Widget _welcome(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: SKSpacing.x12),
        Text(
          'Добро пожаловать\nв Boom Bala',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: SKSpacing.x5),
        Text(
          'Настроим профиль семьи — это поможет быстрее оформлять посещения '
          'и праздники.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _parent(BuildContext context) {
    return _section(
      context,
      eyebrow: 'Шаг 1 из 3',
      title: 'Как вас зовут?',
      child: TextField(
        controller: _parentNameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        maxLength: 50,
        decoration: const InputDecoration(labelText: 'Имя'),
      ),
    );
  }

  Widget _family(BuildContext context) {
    return _section(
      context,
      eyebrow: 'Шаг 2 из 3',
      title: 'Расскажите о семье',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Даты рождения помогают не пропускать важные события, а данные '
            'ребёнка упрощают заявку на праздник.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: SKSpacing.x5),
          if (_children.isEmpty)
            Text(
              'Детей пока можно не добавлять — это можно сделать позже в профиле.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (var index = 0; index < _children.length; index++) ...[
              _childCard(context, _children[index], index),
              const SizedBox(height: SKSpacing.x3),
            ],
          OutlinedButton.icon(
            onPressed: _addChild,
            icon: const Icon(Icons.add),
            label: Text(
              _children.isEmpty ? 'Добавить ребёнка' : 'Добавить ещё ребёнка',
            ),
          ),
          if (_children.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _next,
                child: const Text('Сделать позже'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _childCard(BuildContext context, _ChildFormState child, int index) {
    final date = child.birthDate == null
        ? ''
        : MaterialLocalizations.of(context).formatMediumDate(child.birthDate!);
    final gender = switch (child.gender) {
      ChildGender.male => 'Мальчик',
      ChildGender.female => 'Девочка',
      ChildGender.unspecified => null,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(SKSpacing.x4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name.text,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: SKSpacing.x1),
                  Text(
                    [
                      date,
                      if (gender != null) gender,
                    ].where((e) => e.isNotEmpty).join(' · '),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Действия',
              onSelected: (value) {
                if (value == 'edit') _editChild(index);
                if (value == 'delete') _removeChild(index);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Изменить')),
                PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _consent(BuildContext context) {
    return _section(
      context,
      eyebrow: 'Шаг 3 из 3',
      title: 'Почти готово',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Подтвердите согласие на обработку данных профиля семьи, чтобы '
            'завершить настройку.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: SKSpacing.x4),
          CheckboxListTile(
            value: _consentAccepted,
            onChanged: (value) =>
                setState(() => _consentAccepted = value ?? false),
            title: const Text('Я согласен(а) на обработку персональных данных'),
            subtitle: _privacyPolicySubtitle(),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  Widget _privacyPolicySubtitle() {
    final policyUrl = AppEnvironment.privacyPolicyUrl.trim();
    if (policyUrl.isEmpty) {
      return const Text(
        'Политика конфиденциальности будет подключена перед production-релизом.',
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Ознакомьтесь с '),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(policyUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('политикой конфиденциальности'),
        ),
        const Text(' перед продолжением.'),
      ],
    );
  }

  Widget _section(
    BuildContext context, {
    required String eyebrow,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: theme.textTheme.labelMedium),
        const SizedBox(height: SKSpacing.x2),
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: SKSpacing.x6),
        child,
      ],
    );
  }
}

class _ChildFormState {
  _ChildFormState({
    String? name,
    this.birthDate,
    this.gender = ChildGender.unspecified,
  }) {
    this.name.text = name ?? '';
  }

  final TextEditingController name = TextEditingController();
  DateTime? birthDate;
  ChildGender gender;

  void dispose() => name.dispose();
}

class _ChildDraftResult {
  const _ChildDraftResult({
    required this.name,
    required this.birthDate,
    required this.gender,
  });

  final String name;
  final DateTime birthDate;
  final ChildGender gender;

  _ChildFormState toFormState() =>
      _ChildFormState(name: name, birthDate: birthDate, gender: gender);
}

class _ChildEditorDialog extends StatefulWidget {
  const _ChildEditorDialog({this.initial});

  final _ChildFormState? initial;

  @override
  State<_ChildEditorDialog> createState() => _ChildEditorDialogState();
}

class _ChildEditorDialogState extends State<_ChildEditorDialog> {
  late final TextEditingController _nameController;
  late DateTime? _birthDate = widget.initial?.birthDate;
  late ChildGender _gender = widget.initial?.gender ?? ChildGender.unspecified;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initial?.name.text ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Дата рождения',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = DateUtils.dateOnly(picked));
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите имя ребёнка.');
      return;
    }
    if (_birthDate == null) {
      setState(() => _error = 'Укажите дату рождения.');
      return;
    }
    Navigator.of(context).pop(
      _ChildDraftResult(name: name, birthDate: _birthDate!, gender: _gender),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Добавить ребёнка' : 'Изменить данные',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Имя ребёнка'),
            ),
            InkWell(
              onTap: _pickBirthDate,
              borderRadius: BorderRadius.circular(SKRadius.md),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Дата рождения'),
                child: Text(
                  _birthDate == null
                      ? 'Выберите дату'
                      : MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(_birthDate!),
                ),
              ),
            ),
            const SizedBox(height: SKSpacing.x4),
            Text(
              'Пол (необязательно)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: SKSpacing.x2),
            Wrap(
              spacing: SKSpacing.x2,
              children: [
                _genderChoice(ChildGender.male, 'Мальчик'),
                _genderChoice(ChildGender.female, 'Девочка'),
                _genderChoice(ChildGender.unspecified, 'Не указывать'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: SKSpacing.x3),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  Widget _genderChoice(ChildGender value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _gender == value,
      onSelected: (_) => setState(() => _gender = value),
    );
  }
}
