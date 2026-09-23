from __future__ import annotations

from fastapi import status

from ...core.exceptions.http import DomainHTTPException
from ...db.models.mobile_user import MobileUser
from ...db.repositories.mobile_child_repository import MobileChildRepository
from ...db.repositories.customer_pass_repository import CustomerPassRepository
from ...db.repositories.mobile_payment_repository import MobilePaymentRepository
from .schemas import (
    ChildCreateRequest,
    ChildListResponse,
    ChildResponse,
    ChildUpdateRequest,
)


class MobileChildrenService:
    def __init__(
        self,
        *,
        child_repository: MobileChildRepository,
        customer_pass_repository: CustomerPassRepository,
        payment_repository: MobilePaymentRepository,
    ) -> None:
        self._repo = child_repository
        self._customer_passes = customer_pass_repository
        self._payments = payment_repository

    def list_children(self, user: MobileUser) -> ChildListResponse:
        children = self._repo.list_for_user(user.id)
        return ChildListResponse(items=[ChildResponse.from_model(c) for c in children])

    def create_child(self, user: MobileUser, payload: ChildCreateRequest) -> ChildResponse:
        child = self._repo.create(
            user_id=user.id,
            name=payload.name,
            birth_date=payload.birthDate,
            gender=payload.gender.value,
        )
        return ChildResponse.from_model(child)

    def update_child(
        self,
        user: MobileUser,
        child_id: str,
        payload: ChildUpdateRequest,
    ) -> ChildResponse:
        child = self._repo.get_by_id_and_user(child_id, user.id)
        if child is None:
            raise DomainHTTPException(
                code='child_not_found',
                message='Child not found.',
                status_code=status.HTTP_404_NOT_FOUND,
            )

        fields_set = payload.model_fields_set
        update_kwargs: dict = {}
        if 'name' in fields_set and payload.name is not None:
            update_kwargs['name'] = payload.name
        if 'birthDate' in fields_set and payload.birthDate is not None:
            update_kwargs['birth_date'] = payload.birthDate
        if 'gender' in fields_set and payload.gender is not None:
            update_kwargs['gender'] = payload.gender.value

        if update_kwargs:
            child = self._repo.update(child, **update_kwargs)

        return ChildResponse.from_model(child)

    def delete_child(self, user: MobileUser, child_id: str) -> None:
        child = self._repo.get_by_id_and_user(child_id, user.id, for_update=True)
        if child is None:
            raise DomainHTTPException(
                code='child_not_found',
                message='Child not found.',
                status_code=status.HTTP_404_NOT_FOUND,
            )
        has_pass = (
            self._customer_passes.exists_for_child(child.id)
            or self._payments.has_blocking_pass_payment_for_child(
                mobile_user_id=user.id,
                child_id=child.id,
            )
        )
        if has_pass:
            raise DomainHTTPException(
                code='child_has_pass',
                message='Нельзя удалить ребёнка, пока с ним связан абонемент или незавершённая покупка абонемента.',
                status_code=status.HTTP_409_CONFLICT,
            )
        self._repo.delete(child)
