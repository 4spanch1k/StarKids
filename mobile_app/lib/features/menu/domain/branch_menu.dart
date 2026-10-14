class BranchMenu {
  const BranchMenu({
    required this.branchId,
    required this.categories,
  });

  final String branchId;
  final List<MenuCategory> categories;
}

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<MenuItem> items;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.title,
    required this.priceTenge,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final int priceTenge;
  final String imageUrl;
}
