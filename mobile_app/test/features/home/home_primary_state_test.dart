import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/features/children/domain/child.dart';
import 'package:star_kids_mobile/features/home/presentation/models/home_primary_state.dart';
import 'package:star_kids_mobile/features/tickets/domain/issued_ticket.dart';

void main() {
  final today = DateTime(2026, 9, 1, 13);

  test('ticket has priority over a nearby birthday', () {
    final result = resolveHomePrimaryState(
      tickets: [_ticket(DateTime(2026, 9, 5))],
      children: [_child(DateTime(2019, 9, 20))],
      now: today,
    );

    expect(result.state, HomePrimaryState.activeTicket);
  });

  test('birthday is selected when there is no upcoming ticket', () {
    final result = resolveHomePrimaryState(
      tickets: const [],
      children: [_child(DateTime(2019, 9, 20))],
      now: today,
    );

    expect(result.state, HomePrimaryState.birthday);
    expect(result.child?.name, 'Ася');
    expect(result.birthdayAge, 7);
    expect(result.nextBirthday, DateTime(2026, 9, 20));
  });

  test('past, used and open-date tickets are not active', () {
    final result = resolveHomePrimaryState(
      tickets: [
        _ticket(DateTime(2026, 8, 31)),
        _ticket(null, status: 'used'),
        _ticket(null),
      ],
      children: const [],
      now: today,
    );

    expect(result.state, HomePrimaryState.newFamily);
  });

  test('a known returning family uses returning state without fake counts', () {
    final result = resolveHomePrimaryState(
      tickets: const [],
      children: const [],
      now: today,
      hasVisitHistory: true,
    );

    expect(result.state, HomePrimaryState.returningFamily);
  });
}

Child _child(DateTime birthDate) => Child(
      id: 'child-1',
      name: 'Ася',
      birthDate: birthDate,
      gender: ChildGender.female,
    );

IssuedTicket _ticket(DateTime? visitDate, {String status = 'issued'}) =>
    IssuedTicket(
      ticketId: 'ticket-${visitDate?.day ?? 'open'}-$status',
      ticketNumber: 'BB-0000000001',
      ticketItemId: 'kids',
      title: 'Детский билет',
      branchId: 'branch-1',
      branchName: 'Boom Bala',
      visitDate: visitDate,
      priceTenge: 3700,
      status: status,
      issuedAt: DateTime(2026, 9, 1),
    );
