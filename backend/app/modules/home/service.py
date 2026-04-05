from .schemas import HomeResponse, HomeSection


class HomeService:
    def get_home(self) -> HomeResponse:
        return HomeResponse(
            city='Shymkent',
            sections=[
                HomeSection(
                    key='birthdays',
                    title='Birthdays',
                    description='Primary commercial flow for packages and requests.',
                ),
                HomeSection(
                    key='promotions',
                    title='Promotions',
                    description='Retention-ready offers with push entry points.',
                ),
            ],
        )

