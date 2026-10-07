import 'issued_ticket.dart';

abstract interface class IssuedTicketRepository {
  Future<List<IssuedTicket>> listIssuedTickets();

  Future<IssuedTicket> getIssuedTicket(String ticketId);

  Future<String> getIssuedTicketQrPayload(String ticketId);
}
