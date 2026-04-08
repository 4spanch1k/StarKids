import '../domain/branch_contact_links.dart';

const contactLinkSeedData = <BranchContactLinks>[
  BranchContactLinks(
    branchId: 'shymkent-mega',
    mapUrl:
        'https://maps.google.com/?q=%D0%A8%D1%8B%D0%BC%D0%BA%D0%B5%D0%BD%D1%82%2C%20%D0%90%D0%BB%D1%8C-%D0%A4%D0%B0%D1%80%D0%B0%D0%B1%D0%B8%2C%203%20%D1%8D%D1%82%D0%B0%D0%B6%2C%204%20%D0%BA%D0%B0%D0%B1%D0%B8%D0%BD%D0%B5%D1%82',
    routeLabel: 'Google Maps',
    parkingHint:
        'Удобнее парковаться у главного входа и сразу подниматься на этаж.',
    arrivalHint:
        'Если едете на праздник, лучше заложить 10–15 минут запаса до начала программы.',
  ),
  BranchContactLinks(
    branchId: 'shymkent-center',
    mapUrl:
        'https://maps.google.com/?q=%D0%A8%D1%8B%D0%BC%D0%BA%D0%B5%D0%BD%D1%82%2C%20%D1%86%D0%B5%D0%BD%D1%82%D1%80%D0%B0%D0%BB%D1%8C%D0%BD%D0%B0%D1%8F%20%D0%B7%D0%BE%D0%BD%D0%B0%2C%20%D1%81%D0%B5%D0%BC%D0%B5%D0%B9%D0%BD%D1%8B%D0%B9%20%D1%84%D0%BE%D1%80%D0%BC%D0%B0%D1%82',
    routeLabel: 'Google Maps',
    parkingHint:
        'Для семейного формата лучше заранее посмотреть маршрут и место высадки детей.',
    arrivalHint:
        'Если планируется большой визит, лучше написать менеджеру до приезда.',
  ),
];
