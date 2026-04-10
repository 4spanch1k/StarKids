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
        'Имениннику в день рождения вход бесплатный. Если нужен отдельный праздничный пакет, его удобно открыть в соседнем разделе.',
    disclaimer:
        'Цены указаны для филиала ТРЦ «Аль-Фараби». В праздничные дни действует тариф выходного дня.',
    menuSections: _alFarabiMenuSections,
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
    subtitle: 'Сорпалар',
    imageUrl: _soupsImageUrl,
    items: [
      MenuItem(
        id: 'chicken-noodle-soup',
        title: 'Куриный суп с домашней лапшой',
        priceLabel: '1490 тг',
      ),
      MenuItem(
        id: 'rib-soup',
        title: 'Суп ребра (Қабырғадан жасалған сорпа)',
        priceLabel: '1890 тг',
      ),
      MenuItem(
        id: 'beef-dumplings-soup',
        title: 'Пельмени с говядиной',
        priceLabel: '1390 тг',
      ),
      MenuItem(
        id: 'chicken-dumplings-soup',
        title: 'Пельмени с курицей',
        priceLabel: '1390 тг',
      ),
    ],
  ),
  MenuSection(
    id: 'salads',
    title: 'Салаты',
    subtitle: 'Салаттар',
    imageUrl: _saladsImageUrl,
    items: [
      MenuItem(
        id: 'crispy-eggplants',
        title: 'Хрустящие баклажаны',
        priceLabel: '2190 тг',
      ),
      MenuItem(
        id: 'caesar',
        title: 'Цезарь с курицей',
        priceLabel: '2390 тг',
      ),
      MenuItem(
        id: 'greek-salad',
        title: 'Салат «Греческий»',
        priceLabel: '2390 тг',
      ),
      MenuItem(
        id: 'achuchuk',
        title: 'Салат «Ачучук»',
        priceLabel: '1490 тг',
      ),
      MenuItem(
        id: 'fresh-salad',
        title: 'Салат «Свежий»',
        priceLabel: '1490 тг',
      ),
    ],
  ),
  MenuSection(
    id: 'pizza',
    title: 'Пицца',
    imageUrl: _pizzaImageUrl,
    items: [
      MenuItem(
        id: 'pepperoni',
        title: 'Пепперони',
        priceLabel: '2490 тг',
      ),
      MenuItem(
        id: 'margarita',
        title: 'Маргарита',
        priceLabel: '2390 тг',
      ),
      MenuItem(
        id: 'bolognese',
        title: 'Болоньезе',
        priceLabel: '2890 тг',
      ),
      MenuItem(
        id: 'four-seasons',
        title: '4 сезона',
        priceLabel: '2890 тг',
      ),
      MenuItem(
        id: 'chicken-mushrooms',
        title: 'С курицей и грибами',
        priceLabel: '2890 тг',
      ),
      MenuItem(
        id: 'four-cheese',
        title: '4 сыра',
        priceLabel: '2890 тг',
      ),
    ],
  ),
  MenuSection(
    id: 'main-courses',
    title: 'Вторые блюда',
    subtitle: 'Екінші тағамдар',
    imageUrl: _mainCoursesImageUrl,
    items: [
      MenuItem(
        id: 'manty',
        title: 'Манты домашние',
        priceLabel: '2490 тг',
      ),
      MenuItem(
        id: 'teriyaki-chicken',
        title: 'Курица в соусе терияки',
        priceLabel: '2790 тг',
      ),
      MenuItem(
        id: 'meat-platter',
        title: 'Мясная нарезка',
        priceLabel: '5390 тг',
      ),
      MenuItem(
        id: 'cheese-pasta-sausage',
        title: 'Сырная паста с сосиской',
        priceLabel: '1790 тг',
      ),
      MenuItem(
        id: 'fried-assorted-sour-cream',
        title: 'Жареное ассорти со сметаной',
        priceLabel: '1990 тг',
      ),
    ],
  ),
  MenuSection(
    id: 'fast-food',
    title: 'Фастфуд',
    imageUrl: _fastFoodImageUrl,
    items: [
      MenuItem(
        id: 'nuggets',
        title: 'Наггетсы',
        priceLabel: '1590 тг',
      ),
      MenuItem(
        id: 'cheese-sticks',
        title: 'Сырные палочки',
        priceLabel: '1690 тг',
      ),
      MenuItem(
        id: 'wings',
        title: 'Крылышки (16 шт)',
        priceLabel: '4490 тг',
      ),
      MenuItem(
        id: 'cheeseburger-beef',
        title: 'Чизбургер Beef',
        priceLabel: '2090 тг',
      ),
      MenuItem(
        id: 'cheeseburger-chicken',
        title: 'Чизбургер Chicken',
        priceLabel: '1990 тг',
      ),
      MenuItem(
        id: 'club-sandwich',
        title: 'Клаб-сэндвич',
        priceLabel: '1990 тг',
      ),
      MenuItem(
        id: 'fries',
        title: 'Фри',
        priceLabel: '790 тг',
      ),
      MenuItem(
        id: 'potato-wedges',
        title: 'Картофельные дольки',
        priceLabel: '790 тг',
      ),
      MenuItem(
        id: 'potato-boats',
        title: 'Картофельные лодочки',
        priceLabel: '790 тг',
      ),
    ],
  ),
  MenuSection(
    id: 'tea',
    title: 'Чай',
    subtitle: 'Шайлар',
    imageUrl: _teaImageUrl,
    items: [
      MenuItem(
        id: 'black-green-tea',
        title: 'Черный / Зеленый',
        priceLabel: '990 тг',
      ),
      MenuItem(
        id: 'milk-tea',
        title: 'Чай с молоком',
        priceLabel: '1090 тг',
      ),
      MenuItem(
        id: 'special-tea',
        title:
            'Ташкентский / Фруктовый / Ягодный / Манго-маракуйя / Малина-имбирь',
        priceLabel: '1290 тг',
      ),
    ],
  ),
];
