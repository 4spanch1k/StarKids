import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/core/design_system/widgets/sk_field.dart';

import '../../../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('supports clipboard paste for obscured fields', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': 'copied-secret'};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: SkField(
            controller: controller,
            label: 'Пароль',
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));

    final editableState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    await editableState.pasteText(SelectionChangedCause.toolbar);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(controller.text, 'copied-secret');
    expect(field.enableInteractiveSelection, isTrue);
    expect(field.contextMenuBuilder, isNotNull);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
  });
}
