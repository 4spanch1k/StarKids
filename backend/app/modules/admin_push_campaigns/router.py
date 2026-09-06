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
    PushCampaignResponse,
    PushCampaignUpdateRequest,
)
from .service import PushCampaignService

router = APIRouter(dependencies=[Depends(require_admin_roles('super_admin'))])


def get_service(session: Session = Depends(get_db_session), delivery: PushDeliveryPort = Depends(get_push_delivery)) -> PushCampaignService:
    return PushCampaignService(session, delivery)


@router.get('/push-campaigns', response_model=list[PushCampaignResponse])
def list_campaigns(service: PushCampaignService = Depends(get_service)) -> list[PushCampaignResponse]:
    return service.list()


@router.get('/push-campaigns/{campaign_id}', response_model=PushCampaignResponse, responses={404: {'model': ErrorResponse}})
def get_campaign(campaign_id: str, service: PushCampaignService = Depends(get_service)) -> PushCampaignResponse:
    return service.get(campaign_id)


@router.post('/push-campaigns', response_model=PushCampaignResponse, status_code=status.HTTP_201_CREATED)
def create_campaign(payload: PushCampaignCreateRequest, current_admin: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin')), service: PushCampaignService = Depends(get_service)) -> PushCampaignResponse:
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
