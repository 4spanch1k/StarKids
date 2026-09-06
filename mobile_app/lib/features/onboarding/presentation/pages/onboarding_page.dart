import 'package:flutter/material.dart';

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
  static const _consentVersion = 'v1-pending-legal';

  late final OnboardingController _controller;
  final _parentNameController = TextEditingController();
  final List<_ChildFormState> _children = [];
  int _step = 0;
  int? _selectedCount;
  bool _fourPlus = false;
  bool _consentAccepted = false;
  String? _error;

  int get _childCount => _children.length;
  bool get _isChildStep => _step >= 3 && _step < _finalStep;
  int get _childIndex => _step - 3;
  int get _finalStep => 3 + _children.length;

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
      if (_selectedCount == null) {
        setState(() => _error = 'Выберите количество детей.');
        return;
      }
      setState(() => _step = _childCount == 0 ? _finalStep : 3);
      return;
    }
    if (_isChildStep) {
      final child = _children[_childIndex];
      if (child.name.text.trim().isEmpty) {
        setState(() => _error = 'Введите имя ребёнка.');
        return;
      }
      if (child.birthDate == null) {
        setState(() => _error = 'Укажите дату рождения.');
        return;
      }
      if (_childIndex < _childCount - 1) {
        setState(() => _step++);
      } else {
        setState(() => _step = _finalStep);
      }
      return;
    }
    _submit();
  }

  void _selectCount(int count, {required bool fourPlus}) {
    setState(() {
      _selectedCount = count;
      _fourPlus = fourPlus;
      while (_children.length < count) {
        _children.add(_ChildFormState());
      }
      while (!_fourPlus && _children.length > count) {
        _children.removeLast().dispose();
      }
      _error = null;
    });
  }

  void _addChild() {
    setState(() {
      final wasOnCountStep = _step == 2;
      _children.add(_ChildFormState());
      _selectedCount = _children.length;
      _fourPlus = true;
      _step = wasOnCountStep ? 3 : _children.length + 2;
    });
  }

  Future<void> _pickBirthDate(_ChildFormState child) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          child.birthDate ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateUtils.dateOnly(now),
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
    final drafts = <OnboardingChildDraft>[];
    for (final child in _children) {
      if (child.name.text.trim().isEmpty || child.birthDate == null) {
        setState(() => _error = 'Заполните данные детей.');
        return;
      }
      drafts.add(
        OnboardingChildDraft(
          name: child.name.text.trim(),
          birthDate: child.birthDate!,
          gender: child.gender,
        ),
      );
    }

    final success = await _controller.complete(
      firstName: _parentNameController.text.trim(),
      children: drafts,
      privacyConsentVersion: _consentVersion,
    );
    if (!mounted) return;
    if (success) {
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
    return Scaffold(
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
    );
  }

  Widget _buildStep(BuildContext context) {
    if (_step == 0) return _welcome(context);
    if (_step == 1) return _parent(context);
    if (_step == 2) return _childrenCount(context);
    if (_isChildStep) {
      return _child(context, _children[_childIndex], _childIndex);
    }
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
          'Настроим профиль семьи, чтобы вам было проще покупать билеты, '
          'следить за событиями и не пропускать важные даты.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: SKSpacing.x8),
        Text(
          'Это займёт около минуты.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _parent(BuildContext context) {
    return _section(
      context,
      eyebrow: 'Шаг 1',
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

  Widget _childrenCount(BuildContext context) {
    const options = [0, 1, 2, 3, 4];
    return _section(
      context,
      eyebrow: 'Шаг 2',
      title: 'Сколько у вас детей?',
      child: Column(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: SKSpacing.x2),
              child: ListTile(
                onTap: () => _selectCount(option, fourPlus: option == 4),
                leading: Icon(
                  _selectedCount == option
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _selectedCount == option
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(option == 4 ? '4 и более' : '$option'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (_fourPlus)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addChild,
                icon: const Icon(Icons.add),
                label: const Text('Добавить ещё ребёнка'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _child(BuildContext context, _ChildFormState child, int index) {
    return _section(
      context,
      eyebrow: 'Ребёнок ${index + 1} из $_childCount',
      title: 'Расскажите о ребёнке',
      child: Column(
        children: [
          TextField(
            controller: child.name,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Имя ребёнка'),
          ),
          const SizedBox(height: SKSpacing.x3),
          InkWell(
            onTap: () => _pickBirthDate(child),
            borderRadius: BorderRadius.circular(SKRadius.md),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Дата рождения'),
              child: Text(
                child.birthDate == null
                    ? 'Выберите дату'
                    : MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(child.birthDate!),
              ),
            ),
          ),
          const SizedBox(height: SKSpacing.x4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Пол (необязательно)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: SKSpacing.x2),
          Wrap(
            spacing: SKSpacing.x2,
            runSpacing: SKSpacing.x2,
            children: [
              _genderChoice(child, ChildGender.male, 'Мальчик'),
              _genderChoice(child, ChildGender.female, 'Девочка'),
              _genderChoice(child, ChildGender.unspecified, 'Не указывать'),
            ],
          ),
          if (_fourPlus && index == _childCount - 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addChild,
                icon: const Icon(Icons.add),
                label: const Text('Добавить ещё ребёнка'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _genderChoice(_ChildFormState child, ChildGender value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: child.gender == value,
      onSelected: (_) => setState(() => child.gender = value),
    );
  }

  Widget _consent(BuildContext context) {
    return _section(
      context,
      eyebrow: 'Последний шаг',
      title: 'Почти готово',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Продолжая, вы подтверждаете согласие на обработку данных профиля семьи.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: SKSpacing.x4),
          CheckboxListTile(
            value: _consentAccepted,
            onChanged: (value) =>
                setState(() => _consentAccepted = value ?? false),
            title: const Text('Я согласен(а) на обработку персональных данных'),
            subtitle: const Text(
              'Финальный текст политики будет заменён после юридического утверждения.',
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
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
  final TextEditingController name = TextEditingController();
  DateTime? birthDate;
  ChildGender gender = ChildGender.unspecified;

  void dispose() => name.dispose();
}
