import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/children/domain/child.dart';
import 'package:star_kids_mobile/features/children/domain/children_repository.dart';
import 'package:star_kids_mobile/features/children/presentation/controllers/children_controller.dart';

void main() {
  final child = Child(
    id: 'child-1',
    name: 'Алиса',
    birthDate: DateTime(2020, 1, 2),
    gender: ChildGender.female,
  );

  test('successful delete removes the child and exposes empty state', () async {
    final repository = _FakeChildrenRepository(children: [child]);
    final controller = ChildrenController(repository: repository);

    await controller.load();
    final result = await controller.deleteChild(child.id);

    expect(result, isTrue);
    expect(controller.children, isEmpty);
    expect(controller.status, ChildrenStatus.empty);
    expect(controller.deleteErrorMessage, isNull);
  });

  test(
    'failed delete keeps the child and exposes a visible operation error',
    () async {
      final repository = _FakeChildrenRepository(
        children: [child],
        deleteFailure: 'Не удалось удалить ребёнка.',
      );
      final controller = ChildrenController(repository: repository);

      await controller.load();
      final result = await controller.deleteChild(child.id);

      expect(result, isFalse);
      expect(controller.children, [child]);
      expect(controller.deleteErrorMessage, 'Не удалось удалить ребёнка.');
      expect(controller.formError, isNull);
      controller.clearDeleteError();
      expect(controller.deleteErrorMessage, isNull);
    },
  );
}

class _FakeChildrenRepository implements ChildrenRepository {
  _FakeChildrenRepository({required this.children, this.deleteFailure});

  final List<Child> children;
  final String? deleteFailure;

  @override
  Future<Result<List<Child>>> fetchChildren() async =>
      Success<List<Child>>(children);

  @override
  Future<Result<Child>> createChild({
    required String name,
    required DateTime birthDate,
    required ChildGender gender,
  }) async =>
      const Failure<Child>('not implemented');

  @override
  Future<Result<Child>> updateChild({
    required String childId,
    String? name,
    DateTime? birthDate,
    ChildGender? gender,
  }) async =>
      const Failure<Child>('not implemented');

  @override
  Future<Result<void>> deleteChild(String childId) async {
    if (deleteFailure != null) {
      return Failure<void>(deleteFailure!);
    }
    return const Success<void>(null);
  }
}
