DEFAULT_BRANCH_TICKET_CONFIG = {
    'items': [
        {
            'title': 'Детские билеты 1–3 лет',
            'description': 'Для подтверждения возраста понадобится документ.',
            'price_tenge': 2700,
            'badge_labels': ['Документ обязателен'],
            'display_order': 1,
            'is_active': True,
        },
        {
            'title': 'Детские билеты 4–15 лет',
            'description': 'Базовый билет для посещения игровой зоны.',
            'price_tenge': 3700,
            'badge_labels': [],
            'display_order': 2,
            'is_active': True,
        },
        {
            'title': 'Взрослый билет (сопровождающий)',
            'description': 'Тариф для одного сопровождающего взрослого.',
            'price_tenge': 400,
            'badge_labels': ['Для сопровождающего'],
            'display_order': 3,
            'is_active': True,
        },
    ],
    'notes': [
        {
            'text': 'Детям 0–1 лет — бесплатно',
            'display_order': 1,
            'is_active': True,
        },
        {
            'text': 'Имениннику в день рождения — бесплатно',
            'display_order': 2,
            'is_active': True,
        },
        {
            'text': 'Особенным детям — бесплатно',
            'display_order': 3,
            'is_active': True,
        },
    ],
}
