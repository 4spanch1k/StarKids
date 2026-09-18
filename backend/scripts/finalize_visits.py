"""Finalize active visits that passed their branch validity cutoff."""

from app.core.database.session import SessionLocal
from app.db.repositories.visit_repository import VisitRepository
from app.modules.mobile_payments.visit_finalizer import VisitFinalizer


def main() -> None:
    session = SessionLocal()
    try:
        completed = VisitFinalizer(
            repository=VisitRepository(session),
        ).finalize_due_visits()
        print(f'finalized visits: {completed}')
    finally:
        session.close()


if __name__ == '__main__':
    main()
