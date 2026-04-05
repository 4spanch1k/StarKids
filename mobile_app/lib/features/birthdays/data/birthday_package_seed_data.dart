import '../domain/birthday_package.dart';

const birthdayPackageSeedData = <BirthdayPackage>[
  BirthdayPackage(
    id: 'spark-party',
    name: 'Spark Party',
    priceLabel: 'от 55 000 ₸',
    guestLabel: 'до 10 детей',
    description:
        'Быстрый и яркий формат для семейного праздника без сложной организации.',
    imagePath: 'assets/images/birthday_hero.jpg',
    highlights: [
      'Безлимитная игровая зона',
      'Аниматор 1 час',
      'Фотозона',
      'Праздничный стол',
    ],
  ),
  BirthdayPackage(
    id: 'star-show',
    name: 'Star Show',
    priceLabel: 'от 85 000 ₸',
    guestLabel: 'до 15 детей',
    description:
        'Премиальный пакет с шоу-программой и самым сильным wow-эффектом для гостей.',
    imagePath: 'assets/images/branch_hero.jpg',
    highlights: [
      'Шоу или мастер-класс',
      'Аниматоры',
      'Праздничный стол',
      'Фото и видео атмосфера',
    ],
    isFeatured: true,
  ),
  BirthdayPackage(
    id: 'family-day',
    name: 'Family Day',
    priceLabel: 'от 110 000 ₸',
    guestLabel: 'до 20 детей',
    description:
        'Формат для большого семейного события с запасом по времени и пространству.',
    imagePath: 'assets/images/gallery_1.jpg',
    highlights: [
      'Расширенная зона гостей',
      'Помощь менеджера',
      'Сценарий праздника',
      'Подарки имениннику',
    ],
  ),
];

const birthdayValueHighlights = <String>[
  'Аниматоры и шоу',
  'Безлимитный активити парк',
  'Пакеты под разный бюджет',
  'Быстрая заявка без долгой переписки',
];

