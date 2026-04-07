import '../domain/promotion_offer.dart';

const promotionSeedData = <PromotionOffer>[
  PromotionOffer(
    id: 'mega-weekday-bonus',
    title: 'Будний день без очередей и лишней суеты',
    description:
        'Подходит для семейного визита или спокойной подготовки к празднику в филиале Аль-Фараби.',
    badgeLabel: 'Будни',
    imagePath: 'assets/images/promo_hero.jpg',
    branchIds: ['shymkent-mega'],
    ctaLabel: 'Оставить заявку',
  ),
  PromotionOffer(
    id: 'birthday-upgrade',
    title: 'Апгрейд праздника с шоу-программой',
    description:
        'Если нужен wow-эффект, можно быстро перейти в birthday flow и зафиксировать интерес.',
    badgeLabel: 'Birthday',
    imagePath: 'assets/images/birthday_hero.jpg',
    branchIds: [],
    ctaLabel: 'Подобрать пакет',
  ),
  PromotionOffer(
    id: 'family-return',
    title: 'Повод вернуться всей семьей в выходные',
    description:
        'Промо-подборка для повторного визита: площадка, филиал и быстрый переход к заявке.',
    badgeLabel: 'Weekend',
    imagePath: 'assets/images/gallery_1.jpg',
    branchIds: ['shymkent-center'],
    ctaLabel: 'Оставить заявку',
  ),
];
