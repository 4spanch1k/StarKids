import 'current_visit.dart';

abstract interface class CurrentVisitRepository {
  Future<CurrentVisit?> getCurrentVisit();

  Future<VisitHistory> getVisitHistory();
}
