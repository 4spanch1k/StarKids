import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/core/design_system/widgets/star_kids_media_image.dart';

void main() {
  group('resolveMediaImageSource', () {
    test('keeps bundled assets unchanged', () {
      expect(
        resolveMediaImageSource('assets/images/branch_hero.jpg'),
        'assets/images/branch_hero.jpg',
      );
    });

    test('maps legacy branch image identifiers to bundled assets', () {
      expect(
        resolveMediaImageSource('gallery_1'),
        'assets/images/gallery_1.jpg',
      );
    });

    test('resolves root-relative backend media against the API host', () {
      expect(
        resolveMediaImageSource('/media/branches/hero.jpg'),
        'http://localhost:8000/media/branches/hero.jpg',
      );
    });

    test('returns null for an empty source', () {
      expect(resolveMediaImageSource('  '), isNull);
    });
  });
}
