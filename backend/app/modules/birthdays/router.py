from fastapi import APIRouter

from .schemas import BirthdayPackageSummary
from .service import BirthdayService

router = APIRouter()
service = BirthdayService()


@router.get('/birthday-packages', response_model=list[BirthdayPackageSummary])
def list_birthday_packages() -> list[BirthdayPackageSummary]:
    return service.list_packages()

