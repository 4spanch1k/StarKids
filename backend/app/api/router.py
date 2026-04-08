from fastapi import APIRouter

from ..modules.admin_auth.router import router as admin_auth_router
from ..modules.birthdays.router import router as birthdays_router
from ..modules.branches.router import router as branches_router
from ..modules.health.router import router as health_router
from ..modules.home.router import router as home_router
from ..modules.leads.router import router as leads_router
from ..modules.mobile_auth.router import router as mobile_auth_router
from ..modules.notifications.router import router as notifications_router
from ..modules.promotions.router import router as promotions_router

api_router = APIRouter()

api_router.include_router(health_router)
api_router.include_router(mobile_auth_router, prefix='/mobile/auth', tags=['mobile-auth'])
api_router.include_router(home_router, prefix='/mobile', tags=['mobile-home'])
api_router.include_router(branches_router, prefix='/mobile', tags=['mobile-branches'])
api_router.include_router(birthdays_router, prefix='/mobile', tags=['mobile-birthdays'])
api_router.include_router(promotions_router, prefix='/mobile', tags=['mobile-promotions'])
api_router.include_router(leads_router, prefix='/mobile', tags=['mobile-leads'])
api_router.include_router(
    notifications_router,
    prefix='/mobile',
    tags=['mobile-notifications'],
)
api_router.include_router(admin_auth_router, prefix='/admin/auth', tags=['admin-auth'])
