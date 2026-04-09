import 'public_content_block.dart';
import 'public_faq_item.dart';

abstract interface class PublicContentRepository {
  Future<List<PublicContentBlock>> listContentBlocks({
    required String surface,
  });

  Future<List<PublicFaqItem>> listFaqs();
}
