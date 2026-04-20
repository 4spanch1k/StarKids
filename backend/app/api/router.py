from fastapi import APIRouter

from ..modules.admin_auth.router import router as admin_auth_router
from ..modules.admin_birthday_packages.router import router as admin_birthday_packages_router
from ..modules.admin_branches.router import router as admin_branches_router
from ..modules.admin_content.router import router as admin_content_router
from ..modules.admin_leads.router import router as admin_leads_router
from ..modules.admin_news.router import router as admin_news_router
from ..modules.admin_promotions.router import router as admin_promotions_router
from ..modules.birthdays.router import router as birthdays_router
from ..modules.branches.router import router as branches_router
from ..modules.content.router import router as content_router
from ..modules.health.router import router as health_router
from ..modules.home.router import router as home_router
from ..modules.leads.router import router as leads_router
from ..modules.mobile_auth.router import router as mobile_auth_router
from ..modules.mobile_children.router import router as mobile_children_router
from ..modules.mobile_payments.router import mobile_router as mobile_payments_router
from ..modules.mobile_payments.router import public_router as public_payments_router
from ..modules.mobile_profile.router import router as mobile_profile_router
from ..modules.mobile_request_history.router import router as mobile_request_history_router
from ..modules.news.router import router as news_router
from ..modules.notifications.router import router as notifications_router
from ..modules.promotions.router import router as promotions_router

api_router = APIRouter()

api_router.include_router(health_router)
api_router.include_router(mobile_auth_router, prefix='/mobile/auth', tags=['mobile-auth'])
api_router.include_router(mobile_profile_router, prefix='/mobile', tags=['mobile-profile'])
api_router.include_router(mobile_children_router, prefix='/mobile', tags=['mobile-children'])
api_router.include_router(home_router, prefix='/mobile', tags=['mobile-home'])
api_router.include_router(branches_router, prefix='/mobile', tags=['mobile-branches'])
api_router.include_router(birthdays_router, prefix='/mobile', tags=['mobile-birthdays'])
api_router.include_router(promotions_router, prefix='/mobile', tags=['mobile-promotions'])
api_router.include_router(news_router, prefix='/mobile', tags=['mobile-news'])
api_router.include_router(content_router, prefix='/mobile', tags=['mobile-content'])
api_router.include_router(leads_router, prefix='/mobile', tags=['mobile-leads'])
api_router.include_router(
    mobile_request_history_router,
    prefix='/mobile',
    tags=['mobile-requests-history'],
)
api_router.include_router(
    notifications_router,
    prefix='/mobile',
    tags=['mobile-notifications'],
)
api_router.include_router(
    mobile_payments_router,
    prefix='/mobile',
    tags=['mobile-payments'],
)
api_router.include_router(
    public_payments_router,
    prefix='/public',
    tags=['public-payments'],
)
api_router.include_router(admin_auth_router, prefix='/admin/auth', tags=['admin-auth'])
api_router.include_router(admin_branches_router, prefix='/admin', tags=['admin-branches'])
api_router.include_router(
    admin_birthday_packages_router,
    prefix='/admin',
    tags=['admin-birthday-packages'],
)
api_router.include_router(admin_promotions_router, prefix='/admin', tags=['admin-promotions'])
api_router.include_router(admin_news_router, prefix='/admin', tags=['admin-news'])
api_router.include_router(admin_content_router, prefix='/admin', tags=['admin-content'])
api_router.include_router(admin_leads_router, prefix='/admin', tags=['admin-leads'])
