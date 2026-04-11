import '../domain/birthday_package.dart';

const birthdayPackageSeedData = <BirthdayPackage>[
  BirthdayPackage(
    id: 'magic-party',
    name: 'MAGIC PARTY',
    priceLabel: '27 990 тг',
    guestLabel: 'Старая цена 39 990 тг',
    description:
        'Самый популярный пакет для полного семейного праздника в рабочие дни.',
    imagePath: 'assets/images/birthday_hero.jpg',
    highlights: [
      'Кабинка на 5 часов',
      'Аниматор 1.5 часа',
      'Квест на выбор: Бравл Старс, Гарри Поттер, Барби, Майнкрафт, Игра в кальмара, Национальный, Роблокс, Супергеройский',
      'Шоу, поздравление и мастер-класс по шарам',
    ],
    isFeatured: true,
  ),
  BirthdayPackage(
    id: 'star-party',
    name: 'STAR PARTY',
    priceLabel: '55 990 тг',
    guestLabel: 'Старая цена 79 990 тг',
    description:
        'VIP пакет с безлимитной кабинкой, двумя аниматорами и расширенной шоу-программой.',
    imagePath: 'assets/images/branch_hero.jpg',
    highlights: [
      'Кабинка безлимит',
      '2 аниматора на 2 часа',
      '2 шоу, ростовая кукла и пиньята',
      'Мастер-класс на выбор: антистресс, радуга в бутылке, фокусы, слайм, брелок, пенная, азотное мороженое',
    ],
  ),
  BirthdayPackage(
    id: 'wow-party',
    name: 'WOW PARTY',
    priceLabel: '20 990 тг',
    guestLabel: 'Старая цена 29 990 тг',
    description:
        'Самый доступный пакет с понятным сценарием и без лишнего перегруза.',
    imagePath: 'assets/images/gallery_1.jpg',
    highlights: [
      'Кабинка на 3 часа',
      'Аниматор на 1 час',
      'Анимация 30 минут',
      'Поздравление и мастер-класс по шарам',
    ],
  ),
];

const birthdayValueHighlights = <String>[
  'Аниматоры и шоу',
  'Безлимитный активити парк',
  'Пакеты под разный бюджет',
  'Быстрая заявка без долгой переписки',
];

BirthdayPackage? getBirthdayPackageById(String? packageId) {
  for (final item in birthdayPackageSeedData) {
    if (item.id == packageId) {
      return item;
    }
  }

  return null;
}
