import 'package:flutter/material.dart';

/// Simple compile-time localisation for Russian (default) and Kazakh.
/// Retrieve via [AppL10n.of(context)].
class AppL10n {
  const AppL10n._(this._kk);

  final bool _kk;

  static AppL10n of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final isKk = locale?.languageCode == 'kk';
    return AppL10n._(isKk);
  }

  // ─── App-wide ─────────────────────────────────────────────────────────────

  String get appTitle => _kk ? 'Star Kids' : 'Star Kids';

  // ─── Navigation ───────────────────────────────────────────────────────────

  String get navHome => _kk ? 'Басты' : 'Главная';
  String get navBirthdays => _kk ? 'Туған күн' : 'Дни рождения';
  String get navMenu => _kk ? 'Мәзір' : 'Меню';
  String get navProfile => _kk ? 'Профиль' : 'Профиль';
  String get navPromotions => _kk ? 'Акциялар' : 'Акции';

  // ─── Common ───────────────────────────────────────────────────────────────

  String get save => _kk ? 'Сақтау' : 'Сохранить';
  String get cancel => _kk ? 'Болдырмау' : 'Отмена';
  String get retry => _kk ? 'Қайталау' : 'Повторить';
  String get add => _kk ? 'Қосу' : 'Добавить';
  String get edit => _kk ? 'Өзгерту' : 'Редактировать';
  String get delete => _kk ? 'Жою' : 'Удалить';
  String get loading => _kk ? 'Жүктелуде…' : 'Загрузка…';
  String get error => _kk ? 'Қате' : 'Ошибка';

  // ─── Profile page ─────────────────────────────────────────────────────────

  String get profileTitle => _kk ? 'Профиль' : 'Профиль';
  String get profileDefault => _kk ? 'Star Kids профилі' : 'Профиль Star Kids';
  String get personalData => _kk ? 'Жеке деректер' : 'Личные данные';
  String get firstName => _kk ? 'Аты' : 'Имя';
  String get lastName => _kk ? 'Тегі' : 'Фамилия';
  String get email => _kk ? 'Email' : 'Email';
  String get profileLoadError =>
      _kk ? 'Профиль жүктелмеді' : 'Не удалось загрузить профиль';
  String get profileLoadErrorHint =>
      _kk ? 'Қайталап көріңіз.' : 'Попробуйте снова.';
  String get saveSuccess => _kk ? 'Сақталды' : 'Сохранено';

  // ─── Branch section ───────────────────────────────────────────────────────

  String get myBranch => _kk ? 'Менің бөлімшем' : 'Мой филиал';
  String get changeBranch => _kk ? 'Бөлімшені өзгерту' : 'Изменить филиал';

  // ─── Requests section ─────────────────────────────────────────────────────

  String get myRequests => _kk ? 'Менің өтінімдерім' : 'Мои заявки';
  String get allRequests => _kk ? 'Барлық өтінімдер' : 'Все заявки';
  String get noRequests => _kk ? 'Өтінімдер жоқ.' : 'Заявок ещё нет.';
  String get requestsLoadError =>
      _kk ? 'Өтінімдер жүктелмеді.' : 'Ошибка загрузки заявок.';
  String moreRequests(int count) =>
      _kk ? 'Тағы $count өтінім' : 'Ещё $count заявок';

  // ─── Settings ─────────────────────────────────────────────────────────────

  String get settings => _kk ? 'Параметрлер' : 'Настройки';
  String get pushNotifications =>
      _kk ? 'Push-хабарламалар' : 'Push-уведомления';
  String get notifEnabled => _kk ? 'Қосулы' : 'Включены';
  String get notifDisabled => _kk ? 'Өшірулі' : 'Выключены';
  String get notifUnknown => _kk ? 'Сұралмаған' : 'Не запрашивалось';
  String get notifUnavailable => _kk ? 'Қол жетімсіз' : 'Недоступно';

  // ─── Language ─────────────────────────────────────────────────────────────

  String get language => _kk ? 'Тіл' : 'Язык';
  String get langRu => 'Русский';
  String get langKk => 'Қазақша';

  // ─── Theme ────────────────────────────────────────────────────────────────

  String get theme => _kk ? 'Тақырып' : 'Тема';
  String get themeLight => _kk ? 'Ашық' : 'Светлая';
  String get themeDark => _kk ? 'Күңгірт' : 'Тёмная';

  // ─── Children ─────────────────────────────────────────────────────────────

  String get children => _kk ? 'Балалар' : 'Дети';
  String get addChild => _kk ? 'Бала қосу' : 'Добавить ребёнка';
  String get editChild => _kk ? 'Балаға өзгерту' : 'Редактировать';
  String get childName => _kk ? 'Баланың аты' : 'Имя ребёнка';
  String get childBirthDate => _kk ? 'Туған күні' : 'Дата рождения';
  String get childGender => _kk ? 'Жынысы' : 'Пол';
  String get genderBoy => _kk ? 'Ұл бала' : 'Мальчик';
  String get genderGirl => _kk ? 'Қыз бала' : 'Девочка';
  String get noChildren => _kk ? 'Балалар жоқ.' : 'Дети не добавлены.';
  String get addChildSheetTitle => _kk ? 'Баланы қосыңыз' : 'Добавьте ребенка';
  String get childrenEmptyHint => _kk
      ? 'Баланың аты, туған күні және жынысын сақтап қойыңыз.'
      : 'Сохраните имя, дату рождения и пол, чтобы профиль ребенка был всегда под рукой.';
  String get childFormHint => _kk
      ? 'Атын, туған күнін және жынысын көрсетіңіз. Бұл деректер билеттер мен еске салулар үшін қажет.'
      : 'Укажите имя, дату рождения и пол. Эти данные пригодятся для билетов и напоминаний.';
  String get childrenLoadError =>
      _kk ? 'Балалар жүктелмеді.' : 'Не удалось загрузить детей.';
  String get childrenSaveError =>
      _kk ? 'Сақтау кезінде қате.' : 'Ошибка при сохранении.';
  String get childNameRequired => _kk ? 'Аты міндетті.' : 'Имя обязательно.';
  String get childBirthDateRequired =>
      _kk ? 'Туған күні міндетті.' : 'Дата рождения обязательна.';
  String get childGenderRequired => _kk ? 'Жынысын таңдаңыз.' : 'Выберите пол.';
  String get childNameTooLong => _kk ? 'Аты тым ұзын.' : 'Имя слишком длинное.';
  String get confirmDeleteChild =>
      _kk ? 'Баланы жоямыз ба?' : 'Удалить ребёнка?';
  String get childBirthDateFuture =>
      _kk ? 'Болашақ күн болмасын.' : 'Дата не может быть в будущем.';
  String get childTooOld => _kk
      ? 'Ребёнку не может быть больше 18 лет.'
      : 'Ребёнку не может быть больше 18 лет.';

  // ─── Birthday reminder ────────────────────────────────────────────────────

  String birthdayReminderTitle(String name) =>
      _kk ? '$name — бүгін туған күн! 🎂' : 'Сегодня день рождения — $name! 🎂';
  String get birthdayFreeEntry => _kk
      ? 'Именинникке туған күнінде — тегін'
      : 'Имениннику в день рождения — бесплатно';
  String get birthdayPackageHint => _kk
      ? 'Туған күнді мерекелеу үшін пакет таңдауға болады'
      : 'Можно выбрать пакет для празднования дня рождения';
  String get chooseBirthdayPackage => _kk ? 'Пакет таңдау' : 'Выбрать пакет';

  // ─── Logout ───────────────────────────────────────────────────────────────

  String get logout => _kk ? 'Шығу' : 'Выйти';
  String get version => _kk ? 'Нұсқа' : 'Версия';

  // ─── Date picker ──────────────────────────────────────────────────────────

  String get datePickerHelpText =>
      _kk ? 'Туған күнін таңдаңыз' : 'Выберите дату рождения';
  String get datePickerCancel => _kk ? 'Болдырмау' : 'Отмена';
  String get datePickerConfirm => _kk ? 'Таңдау' : 'Выбрать';
  String get dateNotSet => _kk ? 'Белгіленбеген' : 'Не указана';
}
