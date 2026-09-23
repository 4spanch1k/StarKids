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
  static const _minChildren = 1;
  static const _maxChildren = 20;

  late final OnboardingController _controller;
  final _parentFirstNameController = TextEditingController();
  final _parentLastNameController = TextEditingController();
  final List<_ChildFormState> _children = [_ChildFormState()];
  int _childCount = _minChildren;
  int _step = 0;
  bool _consentAccepted = false;
  String? _error;

  int get _consentStep => _childCount + 3;
  bool get _isChildStep => _step >= 3 && _step < _consentStep;
  int get _currentChildIndex => _step - 3;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ServiceRegistry.onboardingController;
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _parentFirstNameController.dispose();
    _parentLastNameController.dispose();
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

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_parentFirstNameController.text.trim().isEmpty) {
        setState(() => _error = 'Введите ваше имя.');
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      _ensureChildSlots(_childCount);
      setState(() => _step = 3);
      return;
    }
    if (_isChildStep) {
      if (!_validateChild(_currentChildIndex)) return;
      setState(() {
        _step = _currentChildIndex == _childCount - 1
            ? _consentStep
            : _step + 1;
      });
      return;
    }
    await _submit();
  }

  bool _validateChild(int index) {
    final child = _children[index];
    if (child.name.text.trim().isEmpty) {
      setState(() => _error = 'Введите имя ребёнка.');
      return false;
    }
    if (child.birthDate == null) {
      setState(() => _error = 'Укажите дату рождения.');
      return false;
    }
    return true;
  }

  int get _filledChildCount => _children
      .take(_childCount)
      .where(
        (child) =>
            child.name.text.trim().isNotEmpty || child.birthDate != null,
      )
      .length;

  void _changeChildCount(int delta) {
    final next = (_childCount + delta).clamp(_minChildren, _maxChildren);
    if (next == _childCount) return;
    if (next < _filledChildCount) {
      setState(() => _error = 'Сначала удалите данные лишних детей.');
      return;
    }
    _ensureChildSlots(next);
    setState(() {
      _childCount = next;
      _error = null;
    });
  }

  void _ensureChildSlots(int count) {
    while (_children.length < count) {
      _children.add(_ChildFormState());
    }
    while (_children.length > count) {
      _children.removeLast().dispose();
    }
  }

  Future<void> _pickBirthDate(int index) async {
    final child = _children[index];
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: child.birthDate ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Дата рождения',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked != null && mounted) {
      setState(() {
        child.birthDate = DateUtils.dateOnly(picked);
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_consentAccepted) {
      setState(() => _error = 'Подтвердите согласие, чтобы продолжить.');
      return;
    }
    for (var index = 0; index < _childCount; index++) {
      if (!_validateChild(index)) {
        setState(() => _step = 3 + index);
        return;
      }
    }

    final drafts = [
      for (final child in _children.take(_childCount))
        OnboardingChildDraft(
          name: child.name.text.trim(),
          birthDate: child.birthDate!,
          gender: child.gender,
        ),
    ];

    final success = await _controller.complete(
      firstName: _parentFirstNameController.text.trim(),
      lastName: _parentLastNameController.text.trim().isEmpty
          ? null
          : _parentLastNameController.text.trim(),
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
                    value: (_step / _consentStep).clamp(0.0, 1.0),
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
                      : _step == _consentStep
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
    if (_step == 0) return _welcome(context);
    if (_step == 1) return _parent(context);
    if (_step == 2) return _familyCount(context);
    if (_isChildStep) return _childStep(context, _currentChildIndex);
    return _consent(context);
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
      eyebrow: 'Шаг 1',
      title: 'Как вас зовут?',
      child: Column(
        children: [
          TextField(
            controller: _parentFirstNameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: 50,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          TextField(
            controller: _parentLastNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: 'Фамилия (необязательно)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _familyCount(BuildContext context) {
    return _section(
      context,
      eyebrow: 'Шаг 2',
      title: 'Сколько у вас детей?',
      child: Column(
        children: [
          Text(
            'Добавим данные каждого ребёнка, чтобы профиль семьи был полезнее.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: SKSpacing.x8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _childCount > _minChildren
                    ? () => _changeChildCount(-1)
                    : null,
                icon: const Icon(Icons.remove),
                tooltip: 'Уменьшить количество детей',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SKSpacing.x8),
                child: Text(
                  '$_childCount',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              IconButton.filledTonal(
                onPressed: _childCount < _maxChildren
                    ? () => _changeChildCount(1)
                    : null,
                icon: const Icon(Icons.add),
                tooltip: 'Увеличить количество детей',
              ),
            ],
          ),
          const SizedBox(height: SKSpacing.x3),
          Text(
            'От 1 до $_maxChildren',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _childStep(BuildContext context, int index) {
    final child = _children[index];
    final date = child.birthDate == null
        ? 'Выберите дату'
        : MaterialLocalizations.of(context).formatMediumDate(child.birthDate!);
    return _section(
      context,
      eyebrow: 'Ребёнок ${index + 1} из $_childCount',
      title: 'Расскажите о ребёнке',
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(SKSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: child.name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Имя ребёнка'),
              ),
              InkWell(
                onTap: () => _pickBirthDate(index),
                borderRadius: BorderRadius.circular(SKRadius.md),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Дата рождения'),
                  child: Text(date),
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
                  _genderChoice(child, ChildGender.male, 'Мальчик'),
                  _genderChoice(child, ChildGender.female, 'Девочка'),
                  _genderChoice(child, ChildGender.unspecified, 'Не указывать'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genderChoice(_ChildFormState child, ChildGender value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: child.gender == value,
      onSelected: (_) => setState(() {
        child.gender = value;
        _error = null;
      }),
    );
  }

  Widget _consent(BuildContext context) {
    return _section(
      context,
      eyebrow: 'Готово',
      title: 'Почти готово',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Проверьте данные семьи и подтвердите согласие на обработку '
            'персональных данных.',
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
  _ChildFormState() : gender = ChildGender.unspecified;

  final TextEditingController name = TextEditingController();
  DateTime? birthDate;
  ChildGender gender;

  void dispose() => name.dispose();
}
