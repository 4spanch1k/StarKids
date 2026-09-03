import '../../../children/domain/child.dart';
import '../../../tickets/domain/issued_ticket.dart';

/// Resolves Home's primary action without coupling business priority to UI.
enum HomePrimaryState { activeTicket, birthday, returningFamily, newFamily }

class HomePrimaryContext {
  const HomePrimaryContext({
    required this.state,
    this.ticket,
    this.child,
    this.nextBirthday,
    this.birthdayAge,
  });

  final HomePrimaryState state;
  final IssuedTicket? ticket;
  final Child? child;
  final DateTime? nextBirthday;
  final int? birthdayAge;
}

/// Ticket > birthday > known returning family > first purchase.
/// `hasVisitHistory` is explicit because a paid ticket is not a visit.
HomePrimaryContext resolveHomePrimaryState({
  required Iterable<IssuedTicket> tickets,
  required Iterable<Child> children,
  required DateTime now,
  bool hasVisitHistory = false,
  int birthdayWindowDays = 60,
}) {
  final today = homeDateOnly(now);
  final upcoming = tickets
      .where((ticket) => isUpcomingIssuedTicket(ticket, today))
      .toList()
    ..sort(_compareTickets);
  if (upcoming.isNotEmpty) {
    return HomePrimaryContext(
      state: HomePrimaryState.activeTicket,
      ticket: upcoming.first,
    );
  }

  final birthday = _nextBirthdayContext(
    children: children,
    today: today,
    windowDays: birthdayWindowDays,
  );
  if (birthday != null) return birthday;

  return HomePrimaryContext(
    state: hasVisitHistory
        ? HomePrimaryState.returningFamily
        : HomePrimaryState.newFamily,
  );
}

DateTime homeDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isUpcomingIssuedTicket(IssuedTicket ticket, DateTime today) {
  final visitDate = ticket.visitDate;
  if (!ticket.isIssued || visitDate == null) return false;
  return !homeDateOnly(visitDate).isBefore(homeDateOnly(today));
}

int _compareTickets(IssuedTicket a, IssuedTicket b) {
  final aDate = a.visitDate;
  final bDate = b.visitDate;
  if (aDate == null && bDate == null) return 0;
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  return homeDateOnly(aDate).compareTo(homeDateOnly(bDate));
}

HomePrimaryContext? _nextBirthdayContext({
  required Iterable<Child> children,
  required DateTime today,
  required int windowDays,
}) {
  HomePrimaryContext? nearest;
  var nearestDays = windowDays + 1;
  for (final child in children) {
    final birthday = _nextBirthday(child.birthDate, today);
    final days = birthday.difference(today).inDays;
    if (days < 0 || days > windowDays || days >= nearestDays) continue;
    nearestDays = days;
    nearest = HomePrimaryContext(
      state: HomePrimaryState.birthday,
      child: child,
      nextBirthday: birthday,
      birthdayAge: birthday.year - child.birthDate.year,
    );
  }
  return nearest;
}

DateTime _nextBirthday(DateTime birthDate, DateTime today) {
  var birthday = DateTime(today.year, birthDate.month, birthDate.day);
  if (birthday.isBefore(today)) {
    birthday = DateTime(today.year + 1, birthDate.month, birthDate.day);
  }
  return birthday;
}
