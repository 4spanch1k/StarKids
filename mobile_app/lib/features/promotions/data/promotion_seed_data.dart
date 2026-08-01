import '../domain/promotion_offer.dart';

const promotionSeedData = <PromotionOffer>[
  PromotionOffer(
    id: 'weekday-ticket-bonus',
    title: 'После школы: 3 часа по цене 2',
    description:
        'Приходите с понедельника по четверг после 16:00. Дополнительный час активити-парка уже включён.',
    badgeLabel: 'До четверга',
    imagePath: 'assets/images/promo_hero.jpg',
    branchIds: ['shymkent-mega'],
    ctaLabel: 'Купить билет',
  ),
  PromotionOffer(
    id: 'birthday-upgrade',
    title: 'Имениннику вход в подарок',
    description:
        'Выберите готовый пакет на день рождения, а вход для главного героя праздника мы добавим бесплатно.',
    badgeLabel: 'День рождения',
    imagePath: 'assets/images/birthday_hero.jpg',
    branchIds: [],
    ctaLabel: 'Смотреть пакеты',
  ),
  PromotionOffer(
    id: 'family-weekend',
    title: 'Семейный выходной выгоднее вместе',
    description:
        'Скидка 20% на второй детский билет в субботу и воскресенье. Оформите оба билета одной покупкой.',
    badgeLabel: 'Выходные',
    imagePath: 'assets/images/gallery_2.jpg',
    branchIds: ['shymkent-mega'],
    ctaLabel: 'Выбрать билеты',
  ),
  PromotionOffer(
    id: 'party-room-gift',
    title: 'Комната праздника в подарок',
    description:
        'Для компаний от 10 детей подготовим отдельную комнату на два часа. Менеджер поможет собрать сценарий.',
    badgeLabel: 'Для компаний',
    imagePath: 'assets/images/gallery_1.jpg',
    branchIds: [],
    ctaLabel: 'Обсудить праздник',
  ),
  PromotionOffer(
    id: 'parents-coffee',
    title: 'Кофе для родителей за наш счёт',
    description:
        'В будние дни два напитка из кофейной карты включены при покупке семейного визита от трёх билетов.',
    badgeLabel: 'Приятный бонус',
    imagePath: 'assets/images/branch_hero.jpg',
    branchIds: ['shymkent-mega'],
    ctaLabel: 'Уточнить условия',
  ),
];
