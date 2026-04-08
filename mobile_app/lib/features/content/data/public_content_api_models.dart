import '../domain/public_content_block.dart';
import '../domain/public_faq_item.dart';

class PublicContentBlockDto {
  const PublicContentBlockDto({
    required this.id,
    required this.surface,
    required this.key,
    required this.title,
    required this.body,
    required this.ctaLabel,
  });

  final String id;
  final String surface;
  final String key;
  final String title;
  final String body;
  final String? ctaLabel;

  factory PublicContentBlockDto.fromJson(Map<String, dynamic> json) {
    return PublicContentBlockDto(
      id: json['id'] as String,
      surface: json['surface'] as String,
      key: json['key'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      ctaLabel: json['cta_label'] as String?,
    );
  }

  PublicContentBlock toDomain() {
    return PublicContentBlock(
      id: id,
      surface: surface,
      key: key,
      title: title,
      body: body,
      ctaLabel: ctaLabel?.trim().isNotEmpty == true ? ctaLabel!.trim() : null,
    );
  }
}

class PublicFaqItemDto {
  const PublicFaqItemDto({
    required this.id,
    required this.question,
    required this.answer,
  });

  final String id;
  final String question;
  final String answer;

  factory PublicFaqItemDto.fromJson(Map<String, dynamic> json) {
    return PublicFaqItemDto(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
    );
  }

  PublicFaqItem toDomain() {
    return PublicFaqItem(
      id: id,
      question: question,
      answer: answer,
    );
  }
}
