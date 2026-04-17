import '../domain/branch_option.dart';

const branchSeedData = <BranchOption>[
  BranchOption(
    id: 'shymkent-mega',
    name: 'Star Kids Al-Farabi',
    shortLabel: 'Аль-Фараби',
    address: 'Шымкент, Аль-Фараби, 3 этаж, 4 кабинет',
    workingHours: 'Ежедневно 11:00 - 23:00',
    description:
        'Большой активити парк для семейного отдыха, дней рождения и ярких выходных.',
    phone: '+7 707 303 98 18',
    whatsAppPhone: '+7 707 303 98 18',
    heroImagePath: 'assets/images/gallery_2.jpg',
    galleryImagePaths: [
      'assets/images/gallery_1.jpg',
      'assets/images/promo_hero.jpg',
      'assets/images/branch_hero.jpg',
    ],
    facilities: [
      '3000 кв.м',
      'Дни рождения',
      'Аниматоры',
      'Мастер-классы',
      'Безлимитный парк',
    ],
  ),
];

const defaultBranchId = 'shymkent-mega';

BranchOption getBranchById(String? branchId) {
  return branchSeedData.firstWhere(
    (branch) => branch.id == branchId,
    orElse: () => branchSeedData.first,
  );
}
