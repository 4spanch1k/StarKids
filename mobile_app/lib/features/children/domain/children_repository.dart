import '../../../core/utils/result.dart';
import 'child.dart';

abstract class ChildrenRepository {
  Future<Result<List<Child>>> fetchChildren();

  Future<Result<Child>> createChild({
    required String name,
    required DateTime birthDate,
    required ChildGender gender,
  });

  Future<Result<Child>> updateChild({
    required String childId,
    String? name,
    DateTime? birthDate,
    ChildGender? gender,
  });

  Future<Result<void>> deleteChild(String childId);
}
