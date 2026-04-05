class BranchOption {
  const BranchOption({
    required this.id,
    required this.name,
    required this.address,
    required this.workingHours,
    required this.description,
    required this.phone,
    required this.whatsAppPhone,
    required this.heroImagePath,
    required this.galleryImagePaths,
    required this.facilities,
    required this.shortLabel,
  });

  final String id;
  final String name;
  final String address;
  final String workingHours;
  final String description;
  final String phone;
  final String whatsAppPhone;
  final String heroImagePath;
  final List<String> galleryImagePaths;
  final List<String> facilities;
  final String shortLabel;
}
