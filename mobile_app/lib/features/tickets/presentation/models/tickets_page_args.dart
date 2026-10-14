enum TicketsSection { tickets, passes }

class TicketsPageArgs {
  const TicketsPageArgs({this.initialSection = TicketsSection.tickets});

  final TicketsSection initialSection;
}
