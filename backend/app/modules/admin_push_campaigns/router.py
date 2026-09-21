from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...services.push.dependencies import get_push_delivery
from ...services.push.delivery_port import PushDeliveryPort
from ..admin_auth.dependencies import require_admin_roles
from ..admin_auth.schemas import AdminCurrentUserResponse
from .schemas import (
    PushCampaignCreateRequest,
    PushCampaignPreviewRequest,
    PushCampaignPreviewResponse,
    PushCampaignAttributionResponse,
    PushCampaignResponse,
    PushCampaignUpdateRequest,
    FirstSecondVisitReportResponse,
)
from .service import PUSH_CAMPAIGN_ALLOWED_ROLES, PushCampaignService
from .attribution_service import PushCampaignAttributionService
from ..first_second_visit.service import FirstSecondVisitService

router = APIRouter(
    dependencies=[Depends(require_admin_roles(*PUSH_CAMPAIGN_ALLOWED_ROLES))]
)


def get_service(session: Session = Depends(get_db_session), delivery: PushDeliveryPort = Depends(get_push_delivery)) -> PushCampaignService:
    return PushCampaignService(session, delivery)


def get_attribution_service(session: Session = Depends(get_db_session)) -> PushCampaignAttributionService:
    return PushCampaignAttributionService(session)


def get_lifecycle_service(
    session: Session = Depends(get_db_session), delivery: PushDeliveryPort = Depends(get_push_delivery)
) -> FirstSecondVisitService:
    return FirstSecondVisitService(session, PushCampaignService(session, delivery))


@router.get('/push-campaigns', response_model=list[PushCampaignResponse])
def list_campaigns(service: PushCampaignService = Depends(get_service)) -> list[PushCampaignResponse]:
    return service.list()


@router.get('/push-campaigns/first-to-second-visit/report', response_model=FirstSecondVisitReportResponse)
def first_second_visit_report(service: FirstSecondVisitService = Depends(get_lifecycle_service)) -> FirstSecondVisitReportResponse:
    return FirstSecondVisitReportResponse(**service.report().__dict__)


@router.get('/push-campaigns/{campaign_id}', response_model=PushCampaignResponse, responses={404: {'model': ErrorResponse}})
def get_campaign(campaign_id: str, service: PushCampaignService = Depends(get_service)) -> PushCampaignResponse:
    return service.get(campaign_id)


@router.get('/push-campaigns/{campaign_id}/attribution', response_model=PushCampaignAttributionResponse, responses={404: {'model': ErrorResponse}})
def campaign_attribution(campaign_id: str, service: PushCampaignAttributionService = Depends(get_attribution_service)) -> PushCampaignAttributionResponse:
    report = service.report(campaign_id)
    return PushCampaignAttributionResponse(**report.__dict__)


@router.post('/push-campaigns', response_model=PushCampaignResponse, status_code=status.HTTP_201_CREATED)
def create_campaign(payload: PushCampaignCreateRequest, current_admin: AdminCurrentUserResponse = Depends(require_admin_roles(*PUSH_CAMPAIGN_ALLOWED_ROLES)), service: PushCampaignService = Depends(get_service)) -> PushCampaignResponse:
    return service.create(payload, current_admin.id)


@router.patch('/push-campaigns/{campaign_id}', response_model=PushCampaignResponse)
def update_campaign(campaign_id: str, payload: PushCampaignUpdateRequest, service: PushCampaignService = Depends(get_service)) -> PushCampaignResponse:
    return service.update(campaign_id, payload)


@router.post('/push-campaigns/{campaign_id}/send', response_model=PushCampaignResponse)
def send_campaign(campaign_id: str, service: PushCampaignService = Depends(get_service)) -> PushCampaignResponse:
    return service.send(campaign_id)


@router.post('/push-campaigns/{campaign_id}/cancel', response_model=PushCampaignResponse)
def cancel_campaign(campaign_id: str, service: PushCampaignService = Depends(get_service)) -> PushCampaignResponse:
    return service.cancel(campaign_id)


@router.post('/push-campaigns/audience-preview', response_model=PushCampaignPreviewResponse)
def preview_audience(payload: PushCampaignPreviewRequest, service: PushCampaignService = Depends(get_service)) -> PushCampaignPreviewResponse:
    return service.preview(payload.audience)
