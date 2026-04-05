from .schemas import BirthdayPackageSummary


class BirthdayService:
    def list_packages(self) -> list[BirthdayPackageSummary]:
        return [
            BirthdayPackageSummary(
                id='birthday-basic',
                name='Birthday Basic',
                price_from=45000,
                branch_id='branch-1',
            ),
            BirthdayPackageSummary(
                id='birthday-premium',
                name='Birthday Premium',
                price_from=70000,
                branch_id='branch-2',
            ),
        ]

