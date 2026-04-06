# Birthday Request API Contract

Endpoint:

`POST /api/v1/mobile/leads/birthday`

Request body:

```json
{
  "branchId": "shymkent-mega",
  "packageId": "star-show",
  "name": "Айдана",
  "phone": "+77070000000",
  "preferredDate": "2026-04-10",
  "guestCount": 12,
  "comment": "Нужен аниматор и торт"
}
```

Success response:

```json
{
  "requestId": "lead_123",
  "submittedAt": "2026-04-06T12:00:00Z",
  "nextStep": "Менеджер свяжется с вами для подтверждения деталей"
}
```

Error response:

```json
{
  "message": "Не удалось отправить заявку"
}
```

Validation error response:

```json
{
  "message": "Validation error",
  "errors": {
    "phone": ["Введите корректный номер"],
    "preferredDate": ["Дата недоступна"]
  }
}
```
