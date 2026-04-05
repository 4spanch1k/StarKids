from fastapi import APIRouter

from .schemas import HomeResponse
from .service import HomeService

router = APIRouter()
service = HomeService()


@router.get('/home', response_model=HomeResponse)
def get_home() -> HomeResponse:
    return service.get_home()

