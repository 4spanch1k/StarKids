import '../domain/branch_menu.dart';

class BranchMenuDto {
  const BranchMenuDto({
    required this.branchId,
    required this.categories,
  });

  final String branchId;
  final List<MenuCategoryDto> categories;

  factory BranchMenuDto.fromJson(Map<String, dynamic> json) {
    return BranchMenuDto(
      branchId: json['branch_id'] as String? ?? '',
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MenuCategoryDto.fromJson)
          .toList(),
    );
  }

  BranchMenu toDomain() {
    return BranchMenu(
      branchId: branchId,
      categories: categories.map((category) => category.toDomain()).toList(),
    );
  }
}

class MenuCategoryDto {
  const MenuCategoryDto({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<MenuItemDto> items;

  factory MenuCategoryDto.fromJson(Map<String, dynamic> json) {
    return MenuCategoryDto(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MenuItemDto.fromJson)
          .toList(),
    );
  }

  MenuCategory toDomain() {
    return MenuCategory(
      id: id,
      title: title,
      items: items.map((item) => item.toDomain()).toList(),
    );
  }
}

class MenuItemDto {
  const MenuItemDto({
    required this.id,
    required this.title,
    required this.priceTenge,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final int priceTenge;
  final String imageUrl;

  factory MenuItemDto.fromJson(Map<String, dynamic> json) {
    return MenuItemDto(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      priceTenge: (json['price_tenge'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String? ?? '',
    );
  }

  MenuItem toDomain() {
    return MenuItem(
      id: id,
      title: title,
      priceTenge: priceTenge,
      imageUrl: imageUrl,
    );
  }
}
