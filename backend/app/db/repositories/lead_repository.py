from uuid import uuid4

from .base import Repository


class LeadRepository(Repository):
    def create(self, payload: dict[str, str]) -> dict[str, str]:
        return {
            'id': f'lead_{uuid4().hex}',
            'type': payload['type'],
            'status': 'new',
        }

