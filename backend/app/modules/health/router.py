from fastapi import APIRouter

router = APIRouter()


@router.get('/health', summary='API health status')
def get_health() -> dict[str, str]:
    return {'status': 'ok'}

