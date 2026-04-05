from .base import Repository


class BranchRepository(Repository):
    def list_active(self) -> list[dict[str, str | bool]]:
        return [
            {
                'id': 'branch-1',
                'name': 'Star Kids Mega',
                'city': 'Shymkent',
                'address': 'Tamerlan Highway',
                'is_active': True,
            },
            {
                'id': 'branch-2',
                'name': 'Star Kids Center',
                'city': 'Shymkent',
                'address': 'Republic Avenue',
                'is_active': True,
            },
        ]

