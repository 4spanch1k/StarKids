import 'dart:async';

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

  test('stale children load cannot overwrite a newer load', () async {
    final repository = _DeferredChildrenRepository();
    final controller = ChildrenController(repository: repository);

    final loadA = controller.load();
    final loadB = controller.load();

    repository.completeFetch(1, [child]);
    await loadB;

    final childA = Child(
      id: 'child-a',
      name: 'Старые данные',
      birthDate: DateTime(2018, 1, 1),
      gender: ChildGender.male,
    );
    repository.completeFetch(0, [childA]);
    await loadA;

    expect(controller.children, [child]);
  });

  test('stale child mutation cannot overwrite a newer load', () async {
    final repository = _DeferredChildrenRepository();
    final controller = ChildrenController(repository: repository);

    final initialLoad = controller.load();
    repository.completeFetch(0, [child]);
    await initialLoad;

    final childB = Child(
      id: 'child-b',
      name: 'Мадина',
      birthDate: DateTime(2021, 2, 3),
      gender: ChildGender.female,
    );
    final add = controller.addChild(
      name: childB.name,
      birthDate: childB.birthDate,
      gender: childB.gender,
    );
    final reload = controller.load();
    repository.completeFetch(1, [child]);
    await reload;
    repository.completeCreate(childB);
    expect(await add, isFalse);
    expect(controller.children, [child]);
    expect(controller.isSaving, isFalse);
  });
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

class _DeferredChildrenRepository implements ChildrenRepository {
  final List<Completer<Result<List<Child>>>> fetches = [];
  Completer<Result<Child>>? createCompleter;

  void completeFetch(int index, List<Child> children) {
    fetches[index].complete(Success<List<Child>>(children));
  }

  void completeCreate(Child child) {
    createCompleter!.complete(Success<Child>(child));
  }

  @override
  Future<Result<List<Child>>> fetchChildren() {
    final completer = Completer<Result<List<Child>>>();
    fetches.add(completer);
    return completer.future;
  }

  @override
  Future<Result<Child>> createChild({
    required String name,
    required DateTime birthDate,
    required ChildGender gender,
  }) {
    createCompleter = Completer<Result<Child>>();
    return createCompleter!.future;
  }

  @override
  Future<Result<Child>> updateChild({
    required String childId,
    String? name,
    DateTime? birthDate,
    ChildGender? gender,
  }) async =>
      const Failure<Child>('not implemented');

  @override
  Future<Result<void>> deleteChild(String childId) async =>
      const Failure<void>('not implemented');
}
