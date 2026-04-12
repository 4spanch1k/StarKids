import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/features/request_history/domain/request_history_item.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_repository.dart';
import 'package:star_kids_mobile/features/request_history/presentation/controllers/request_history_controller.dart';
import 'package:star_kids_mobile/features/request_history/presentation/pages/request_history_page.dart';
import 'package:star_kids_mobile/features/requests/domain/request_status.dart';
import 'package:star_kids_mobile/features/requests/domain/request_type.dart';

void main() {
  group('RequestHistoryPage', () {
    testWidgets('shows unauthenticated state with a path back to login', (
      WidgetTester tester,
    ) async {
      var didOpenProfile = false;
      final controller = RequestHistoryController(
        repository: _FakeRequestHistoryRepository(
          results: const [RequestHistoryFetchUnauthenticated()],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RequestHistoryPage(
            controller: controller,
            onOpenProfile: () => didOpenProfile = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('История доступна после входа'), findsOneWidget);

      await tester.tap(find.text('Перейти ко входу'));
      await tester.pumpAndSettle();

      expect(didOpenProfile, isTrue);
    });

    testWidgets('shows empty state for an authenticated user with no requests',
        (
      WidgetTester tester,
    ) async {
      final controller = RequestHistoryController(
        repository: _FakeRequestHistoryRepository(
          results: const [
            RequestHistoryFetchSuccess(items: [], total: 0),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: RequestHistoryPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Пока нет заявок'), findsOneWidget);
      expect(find.text('Обновить'), findsWidgets);
    });

    testWidgets('shows loaded history items with birthday details', (
      WidgetTester tester,
    ) async {
      final controller = RequestHistoryController(
        repository: _FakeRequestHistoryRepository(
          results: [
            RequestHistoryFetchSuccess(
              total: 1,
              items: [
                RequestHistoryItem(
                  id: 'request-1',
                  type: RequestType.birthdayRequest,
                  status: RequestStatus.inProgress,
                  createdAt: DateTime.parse('2026-04-09T10:00:00Z'),
                  requestedDate: DateTime(2026, 4, 15),
                  guestCount: 10,
                  notes: 'Нужен фотограф',
                  branch: const RequestHistoryBranchSummary(
                    id: 'branch-main',
                    name: 'Star Kids Main',
                    shortLabel: 'Main',
                  ),
                  package: const RequestHistoryPackageSummary(
                    id: 'package-main',
                    name: 'Spark Party',
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: RequestHistoryPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('День рождения'), findsOneWidget);
      expect(find.text('В работе'), findsOneWidget);
      expect(find.text('Star Kids Main'), findsOneWidget);
      expect(find.text('Spark Party'), findsOneWidget);
      expect(find.text('Нужен фотограф'), findsOneWidget);
    });

    testWidgets('shows error state and retries loading', (
      WidgetTester tester,
    ) async {
      final repository = _FakeRequestHistoryRepository(
        results: [
          const RequestHistoryFetchFailure(
            'Не удалось загрузить заявки. Проверьте интернет и попробуйте снова.',
          ),
          const RequestHistoryFetchSuccess(items: [], total: 0),
        ],
      );
      final controller = RequestHistoryController(repository: repository);

      await tester.pumpWidget(
        MaterialApp(home: RequestHistoryPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Не удалось загрузить историю'), findsOneWidget);

      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();

      expect(find.text('Пока нет заявок'), findsOneWidget);
      expect(repository.callCount, 2);
    });

    testWidgets('refresh action reloads loaded history', (
      WidgetTester tester,
    ) async {
      final repository = _FakeRequestHistoryRepository(
        results: [
          RequestHistoryFetchSuccess(
            total: 1,
            items: [
              RequestHistoryItem(
                id: 'request-1',
                type: RequestType.birthdayRequest,
                status: RequestStatus.newRequest,
                createdAt: DateTime.parse('2026-04-09T10:00:00Z'),
                notes: 'Первая загрузка',
              ),
            ],
          ),
          RequestHistoryFetchSuccess(
            total: 1,
            items: [
              RequestHistoryItem(
                id: 'request-2',
                type: RequestType.contact,
                status: RequestStatus.inProgress,
                createdAt: DateTime.parse('2026-04-09T11:00:00Z'),
                notes: 'Данные после обновления',
              ),
            ],
          ),
        ],
      );
      final controller = RequestHistoryController(repository: repository);

      await tester.pumpWidget(
        MaterialApp(home: RequestHistoryPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Первая загрузка'), findsOneWidget);

      await tester.tap(find.byTooltip('Обновить'));
      await tester.pumpAndSettle();

      expect(find.text('Данные после обновления'), findsOneWidget);
      expect(repository.callCount, 2);
    });

    testWidgets('shows contact fallback notes from shared request type model', (
      WidgetTester tester,
    ) async {
      final controller = RequestHistoryController(
        repository: _FakeRequestHistoryRepository(
          results: [
            RequestHistoryFetchSuccess(
              total: 1,
              items: [
                RequestHistoryItem(
                  id: 'request-3',
                  type: RequestType.contact,
                  status: RequestStatus.newRequest,
                  createdAt: DateTime.parse('2026-04-09T12:00:00Z'),
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: RequestHistoryPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Связь с менеджером'), findsOneWidget);
      expect(
        find.text(
          'Запрос на обратную связь отправлен. Менеджер свяжется с вами по указанному номеру.',
        ),
        findsOneWidget,
      );
    });
  });
}

class _FakeRequestHistoryRepository implements RequestHistoryRepository {
  _FakeRequestHistoryRepository({
    required this.results,
  });

  final List<RequestHistoryFetchResult> results;
  int callCount = 0;

  @override
  Future<RequestHistoryFetchResult> fetchMyRequests() async {
    final index = callCount >= results.length ? results.length - 1 : callCount;
    callCount += 1;
    return results[index];
  }
}
