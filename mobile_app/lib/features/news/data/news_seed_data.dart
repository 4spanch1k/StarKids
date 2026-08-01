import '../domain/news_item.dart';

final newsSeedData = <NewsItem>[
  NewsItem(
    id: 'demo-week-program',
    title: 'Что ждёт детей в Star Kids на этой неделе',
    description:
        'Каждый день проводим мини-дискотеки, игровые челленджи и творческие паузы. Активности входят в обычный входной билет, отдельная запись не нужна.',
    imageUrl:
        'assets/images/645959303_17890733316429584_1469844678684572952_n.jpg',
    createdAt: DateTime.utc(2026, 8, 2, 8, 30),
  ),
  NewsItem(
    id: 'demo-birthday-checklist',
    title: 'Чек-лист идеального детского праздника',
    description:
        'Собрали короткий список: возраст гостей, любимая тема, торт, аниматор и время для свободной игры. Менеджер поможет подобрать пакет под ваш бюджет.',
    imageUrl: 'assets/images/birthday_hero.jpg',
    createdAt: DateTime.utc(2026, 8, 1, 12),
  ),
  NewsItem(
    id: 'demo-family-weekend',
    title: 'План семейного выходного без долгой подготовки',
    description:
        'Выберите удобное время, купите билеты в приложении и покажите их на входе. Кафе и зоны отдыха для родителей работают весь день.',
    imageUrl: 'assets/images/gallery_2.jpg',
    createdAt: DateTime.utc(2026, 7, 31, 10),
  ),
];
