import '../domain/home_promotion.dart';

const homePromotionSeedData = <HomePromotion>[
  HomePromotion(
    id: 'march-program',
    title: 'Программа дня и праздничные активности',
    description:
        'Актуальные активности, шоу и программа дня для семейных визитов и дней рождения.',
    imagePath: 'assets/images/home_hero.jpg',
    badgeLabel: 'Актуально',
  ),
  HomePromotion(
    id: 'weekend-visit',
    title: 'Выходные в Boom Bala',
    description:
        'Посмотреть площадку, выбрать филиал и вернуться на праздник без долгого поиска.',
    imagePath: 'assets/images/promo_hero.jpg',
    badgeLabel: 'Weekend',
  ),
];
