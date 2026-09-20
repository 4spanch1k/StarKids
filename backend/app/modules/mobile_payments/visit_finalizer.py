from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime
import logging

from ...db.repositories.visit_repository import VisitRepository
from .visit_lifecycle import should_complete_visit

logger = logging.getLogger(__name__)


class VisitFinalizer:
    """Completes active visits past their existing branch validity cutoff."""

    def __init__(
        self,
        *,
        repository: VisitRepository,
        now_provider: Callable[[], datetime] | None = None,
    ) -> None:
        self.repository = repository
        self.now_provider = now_provider or (lambda: datetime.now(UTC))

    def finalize_due_visits(self) -> int:
        now = self.now_provider()
        completed = 0
        for visit, payment, branch in self.repository.list_active_with_context():
            if not should_complete_visit(
                visit=visit,
                payment_visit_date=payment.visit_date if payment is not None else None,
                branch=branch,
                now=now,
            ):
                continue

            locked_visit = self.repository.get_by_id_for_update(visit.id)
            if locked_visit is None or locked_visit.status != 'active':
                continue
            locked_visit.status = 'completed'
            locked_visit.ended_at = now
            locked_visit.completion_reason = 'validity_cutoff'
            self.repository.db.add(locked_visit)
            self.repository.db.commit()
            completed += 1
            logger.info(
                'Visit finalized by validity cutoff visit_id=%s payment_id=%s',
                locked_visit.id,
                locked_visit.mobile_payment_id,
            )
        return completed
