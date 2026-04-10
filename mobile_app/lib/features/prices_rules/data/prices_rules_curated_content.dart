import '../../branches/domain/branch_option.dart';
import '../domain/branch_prices_rules.dart';

BranchPricesRules applyCuratedPricesRulesContent({
  required BranchOption branch,
  required BranchPricesRules source,
}) {
  if (!_isAlFarabiBranch(branch)) {
    return source;
  }

  return source.copyWith(
    introTitle: 'ТРЦ «Аль-Фараби»',
    introDescription:
        'Актуальные цены посещения, льготы и меню для филиала. Все тексты ниже даны на русском и собраны без тяжелой таблицы.',
    visitTariffs: const [
      VisitTariff(
        id: 'al-farabi-weekday-1-3',
        title: 'Рабочие дни · дети 1–3 лет',
        priceLabel: '2700 тг',
        description: 'Документ обязателен для подтверждения возраста.',
      ),
      VisitTariff(
        id: 'al-farabi-weekday-4-15',
        title: 'Рабочие дни · дети 4–15 лет',
        priceLabel: '3700 тг',
        description: 'Базовый тариф посещения в будние дни.',
      ),
      VisitTariff(
        id: 'al-farabi-weekday-parent',
        title: 'Рабочие дни · сопровождающий родитель',
        priceLabel: '400 тг',
        description: 'Тариф для одного сопровождающего взрослого.',
      ),
      VisitTariff(
        id: 'al-farabi-weekend-1-3',
        title: 'Выходные и праздники · дети 1–3 лет',
        priceLabel: '3700 тг',
        description: 'Документ обязателен для подтверждения возраста.',
      ),
      VisitTariff(
        id: 'al-farabi-weekend-4-15',
        title: 'Выходные и праздники · дети 4–15 лет',
        priceLabel: '4700 тг',
        description: 'Тариф выходного и праздничного дня.',
      ),
    ],
    rules: const [
      'Для детей 1–3 лет документ обязателен для подтверждения возраста.',
      'Дети 0–1 лет проходят бесплатно.',
      'Имениннику в день рождения вход бесплатный.',
      'Особенным детям вход бесплатный.',
    ],
    birthdayNote:
        'Если нужен отдельный сценарий праздника, можно выбрать пакет ниже или оставить заявку через соседний раздел.',
    disclaimer:
        'Цены указаны для филиала ТРЦ «Аль-Фараби». В праздничные дни действует тариф выходного дня.',
    menuSections: _alFarabiMenuSections,
    birthdayPackages: _alFarabiBirthdayPackages,
  );
}

bool _isAlFarabiBranch(BranchOption branch) {
  final haystack =
      '${branch.id} ${branch.name} ${branch.shortLabel} ${branch.address}'
          .toLowerCase();
  return haystack.contains('al-farabi') || haystack.contains('аль-фараби');
}

const _soupsImageUrl =
    'https://images.pexels.com/photos/5339084/pexels-photo-5339084.jpeg?cs=srgb&dl=pexels-roman-odintsov-5339084.jpg&fm=jpg';
const _saladsImageUrl =
    'https://images.pexels.com/photos/29990630/pexels-photo-29990630.jpeg?cs=srgb&dl=pexels-oleg-kuzma-2147635390-29990630.jpg&fm=jpg';
const _pizzaImageUrl =
    'https://images.pexels.com/photos/31300919/pexels-photo-31300919.jpeg?cs=srgb&dl=pexels-antonio-di-giacomo-64078839-31300919.jpg&fm=jpg';
const _mainCoursesImageUrl =
    'https://images.pexels.com/photos/35064952/pexels-photo-35064952.jpeg?cs=srgb&dl=pexels-anya-dunes-2153945617-35064952.jpg&fm=jpg';
const _fastFoodImageUrl =
    'https://images.pexels.com/photos/14710217/pexels-photo-14710217.jpeg?cs=srgb&dl=pexels-mounir-salah-2974452-14710217.jpg&fm=jpg';
const _teaImageUrl =
    'https://images.pexels.com/photos/8329960/pexels-photo-8329960.jpeg?cs=srgb&dl=pexels-anna-pou-8329960.jpg&fm=jpg';

const _alFarabiMenuSections = <MenuSection>[
  MenuSection(
    id: 'soups',
    title: 'Супы',
    subtitle: 'Горячие первые блюда',
    imageUrl: _soupsImageUrl,
    items: [
      MenuItem(
        id: 'chicken-noodle-soup',
        title: 'Куриный суп с домашней лапшой',
        priceLabel: '1490 тг',
        imageUrl: _soupsImageUrl,
      ),
      MenuItem(
        id: 'rib-soup',
        title: 'Суп из ребрышек',
        priceLabel: '1890 тг',
        imageUrl: _soupsImageUrl,
      ),
      MenuItem(
        id: 'beef-dumplings-soup',
        title: 'Пельмени с говядиной',
        priceLabel: '1390 тг',
        imageUrl: _soupsImageUrl,
      ),
      MenuItem(
        id: 'chicken-dumplings-soup',
        title: 'Пельмени с курицей',
        priceLabel: '1390 тг',
        imageUrl: _soupsImageUrl,
      ),
    ],
  ),
  MenuSection(
    id: 'salads',
    title: 'Салаты',
    subtitle: 'Свежие и сытные салаты',
    imageUrl: _saladsImageUrl,
    items: [
      MenuItem(
        id: 'crispy-eggplants',
        title: 'Хрустящие баклажаны',
        priceLabel: '2190 тг',
        imageUrl: _saladsImageUrl,
      ),
      MenuItem(
        id: 'caesar',
        title: 'Цезарь с курицей',
        priceLabel: '2390 тг',
        imageUrl: _saladsImageUrl,
      ),
      MenuItem(
        id: 'greek-salad',
        title: 'Салат «Греческий»',
        priceLabel: '2390 тг',
        imageUrl: _saladsImageUrl,
      ),
      MenuItem(
        id: 'achuchuk',
        title: 'Салат «Ачучук»',
        priceLabel: '1490 тг',
        imageUrl: _saladsImageUrl,
      ),
      MenuItem(
        id: 'fresh-salad',
        title: 'Салат «Свежий»',
        priceLabel: '1490 тг',
        imageUrl: _saladsImageUrl,
      ),
    ],
  ),
  MenuSection(
    id: 'pizza',
    title: 'Пицца',
    subtitle: 'Классика и насыщенные вкусы',
    imageUrl: _pizzaImageUrl,
    items: [
      MenuItem(
        id: 'pepperoni',
        title: 'Пепперони',
        priceLabel: '2490 тг',
        imageUrl: _pizzaImageUrl,
      ),
      MenuItem(
        id: 'margarita',
        title: 'Маргарита',
        priceLabel: '2390 тг',
        imageUrl: _pizzaImageUrl,
      ),
      MenuItem(
        id: 'bolognese',
        title: 'Болоньезе',
        priceLabel: '2890 тг',
        imageUrl: _pizzaImageUrl,
      ),
      MenuItem(
        id: 'four-seasons',
        title: '4 сезона',
        priceLabel: '2890 тг',
        imageUrl: _pizzaImageUrl,
      ),
      MenuItem(
        id: 'chicken-mushrooms',
        title: 'С курицей и грибами',
        priceLabel: '2890 тг',
        imageUrl: _pizzaImageUrl,
      ),
      MenuItem(
        id: 'four-cheese',
        title: '4 сыра',
        priceLabel: '2890 тг',
        imageUrl: _pizzaImageUrl,
      ),
    ],
  ),
  MenuSection(
    id: 'main-courses',
    title: 'Вторые блюда',
    subtitle: 'Сытные горячие блюда',
    imageUrl: _mainCoursesImageUrl,
    items: [
      MenuItem(
        id: 'manty',
        title: 'Манты домашние',
        priceLabel: '2490 тг',
        imageUrl: _mainCoursesImageUrl,
      ),
      MenuItem(
        id: 'teriyaki-chicken',
        title: 'Курица в соусе терияки',
        priceLabel: '2790 тг',
        imageUrl: _mainCoursesImageUrl,
      ),
      MenuItem(
        id: 'meat-platter',
        title: 'Мясная нарезка',
        priceLabel: '5390 тг',
        imageUrl: _mainCoursesImageUrl,
      ),
      MenuItem(
        id: 'cheese-pasta-sausage',
        title: 'Сырная паста с сосиской',
        priceLabel: '1790 тг',
        imageUrl: _mainCoursesImageUrl,
      ),
      MenuItem(
        id: 'fried-assorted-sour-cream',
        title: 'Жареное ассорти со сметаной',
        priceLabel: '1990 тг',
        imageUrl: _mainCoursesImageUrl,
      ),
    ],
  ),
  MenuSection(
    id: 'fast-food',
    title: 'Фастфуд',
    subtitle: 'Быстрые и популярные позиции',
    imageUrl: _fastFoodImageUrl,
    items: [
      MenuItem(
        id: 'nuggets',
        title: 'Наггетсы',
        priceLabel: '1590 тг',
        imageUrl: _fastFoodImageUrl,
      ),
      MenuItem(
        id: 'cheese-sticks',
        title: 'Сырные палочки',
        priceLabel: '1690 тг',
        imageUrl: _fastFoodImageUrl,
      ),
      MenuItem(
        id: 'wings',
        title: 'Крылышки (16 шт)',
        priceLabel: '4490 тг',
        imageUrl: _fastFoodImageUrl,
      ),
      MenuItem(
        id: 'cheeseburger-beef',
        title: 'Чизбургер Beef',
        priceLabel: '2090 тг',
        imageUrl: _fastFoodImageUrl,
      ),
      MenuItem(
        id: 'cheeseburger-chicken',
        title: 'Чизбургер Chicken',
        priceLabel: '1990 тг',
        imageUrl: _fastFoodImageUrl,
      ),
      MenuItem(
        id: 'club-sandwich',
        title: 'Клаб-сэндвич',
        priceLabel: '1990 тг',
        imageUrl: _fastFoodImageUrl,
      ),
      MenuItem(
        id: 'fries',
        title: 'Фри',
        priceLabel: '790 тг',
        imageUrl: _fastFoodImageUrl,
      ),
      MenuItem(
        id: 'potato-wedges',
        title: 'Картофельные дольки',
        priceLabel: '790 тг',
        imageUrl: _fastFoodImageUrl,
      ),
      MenuItem(
        id: 'potato-boats',
        title: 'Картофельные лодочки',
        priceLabel: '790 тг',
        imageUrl: _fastFoodImageUrl,
      ),
    ],
  ),
  MenuSection(
    id: 'tea',
    title: 'Чай',
    subtitle: 'Классический и фруктовый чай',
    imageUrl: _teaImageUrl,
    items: [
      MenuItem(
        id: 'black-green-tea',
        title: 'Черный / Зеленый',
        priceLabel: '990 тг',
        imageUrl: _teaImageUrl,
      ),
      MenuItem(
        id: 'milk-tea',
        title: 'Чай с молоком',
        priceLabel: '1090 тг',
        imageUrl: _teaImageUrl,
      ),
      MenuItem(
        id: 'special-tea',
        title:
            'Ташкентский / Фруктовый / Ягодный / Манго-маракуйя / Малина-имбирь',
        priceLabel: '1290 тг',
        imageUrl: _teaImageUrl,
      ),
    ],
  ),
];

const _alFarabiBirthdayPackages = <BirthdayPackageOffer>[
  BirthdayPackageOffer(
    id: 'magic-party',
    title: 'MAGIC PARTY',
    badgeLabel: 'Самый популярный',
    subtitle: 'Рабочие дни: 27 990 тг',
    oldPriceLabel: '39 990 тг',
    weekdayPriceLabel: '27 990 тг',
    imagePath: 'assets/images/birthday_hero.jpg',
    features: [
      BirthdayPackageFeature(title: 'Кабинка', details: '5 часов'),
      BirthdayPackageFeature(title: 'Аниматор', details: '1.5 часа'),
      BirthdayPackageFeature(title: 'Анимация', details: '30 мин'),
      BirthdayPackageFeature(
        title: 'Квест',
        details:
            '15 мин: Бравл Старс, Гарри Поттер, Барби, Майнкрафт, Игра в кальмара, Национальный, Роблокс, Супергеройский',
      ),
      BirthdayPackageFeature(title: 'Шоу', details: '15 мин'),
      BirthdayPackageFeature(
        title: 'Поздравление',
        details: '15 мин, на выбор: Торжественная, Волшебная, Ханское',
      ),
      BirthdayPackageFeature(
        title: 'Мастер-класс',
        details: '15 мин по шарам',
      ),
    ],
  ),
  BirthdayPackageOffer(
    id: 'star-party',
    title: 'STAR PARTY',
    badgeLabel: 'VIP пакет',
    subtitle: 'Рабочие дни: 55 990 тг',
    oldPriceLabel: '79 990 тг',
    weekdayPriceLabel: '55 990 тг',
    imagePath: 'assets/images/branch_hero.jpg',
    features: [
      BirthdayPackageFeature(title: 'Кабинка', details: 'безлимит'),
      BirthdayPackageFeature(
          title: 'Аниматоры', details: '2 аниматора на 2 часа'),
      BirthdayPackageFeature(title: 'Анимация', details: '20 мин'),
      BirthdayPackageFeature(
        title: 'Квест',
        details:
            '15 мин: Бравл Старс, Гарри Поттер, Барби, Майнкрафт, Игра в кальмара, Национальный, Роблокс, Супергеройский',
      ),
      BirthdayPackageFeature(title: 'Шоу', details: '2 шоу, 30 мин'),
      BirthdayPackageFeature(
        title: 'Поздравление',
        details: '15 мин, на выбор: Торжественная, Волшебная, Ханское',
      ),
      BirthdayPackageFeature(
        title: 'Мастер-класс',
        details:
            '30 мин: антистресс, радуга в бутылке, фокусы, слайм, брелок, пенная, азотное мороженое',
      ),
      BirthdayPackageFeature(
        title: 'Ростовая кукла',
        details:
            'Мишка Тедди, Зайка, Стич, Бум, Принцесса, Хан Ван, Леди Мисс, Супергерой Кейн, Огненный дракон, Майнкрафт Стив',
      ),
      BirthdayPackageFeature(title: 'Пиньята'),
    ],
  ),
  BirthdayPackageOffer(
    id: 'wow-party',
    title: 'WOW PARTY',
    badgeLabel: 'Самый доступный',
    subtitle: 'Рабочие дни: 20 990 тг',
    oldPriceLabel: '29 990 тг',
    weekdayPriceLabel: '20 990 тг',
    imagePath: 'assets/images/gallery_1.jpg',
    features: [
      BirthdayPackageFeature(title: 'Кабинка', details: '3 часа'),
      BirthdayPackageFeature(title: 'Аниматор', details: '1 час'),
      BirthdayPackageFeature(title: 'Анимация', details: '30 мин'),
      BirthdayPackageFeature(
        title: 'Поздравление',
        details: '15 мин, на выбор: Торжественная, Волшебная, Ханское',
      ),
      BirthdayPackageFeature(
        title: 'Мастер-класс',
        details: '15 мин по шарам',
      ),
    ],
  ),
];
