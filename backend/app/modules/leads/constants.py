from typing import Final, Literal

LeadType = Literal['birthday_request', 'contact']
LeadStatus = Literal[
    'new',
    'contacted',
    'qualified',
    'booked',
    'paid',
    'completed',
    'lost',
    # Legacy values remain readable for historical/contact records.
    'in_progress',
    'confirmed',
    'cancelled',
    'closed',
]

LEAD_TYPE_BIRTHDAY_REQUEST: Final[LeadType] = 'birthday_request'
LEAD_TYPE_CONTACT: Final[LeadType] = 'contact'

LEAD_STATUS_NEW: Final[LeadStatus] = 'new'
LEAD_STATUS_IN_PROGRESS: Final[LeadStatus] = 'in_progress'
LEAD_STATUS_CLOSED: Final[LeadStatus] = 'closed'

LEAD_STATUS_CONTACTED: Final[LeadStatus] = 'contacted'
LEAD_STATUS_QUALIFIED: Final[LeadStatus] = 'qualified'
LEAD_STATUS_BOOKED: Final[LeadStatus] = 'booked'
LEAD_STATUS_PAID: Final[LeadStatus] = 'paid'
LEAD_STATUS_COMPLETED: Final[LeadStatus] = 'completed'
LEAD_STATUS_LOST: Final[LeadStatus] = 'lost'

LOST_REASON_TOO_EXPENSIVE: Final[str] = 'too_expensive'
LOST_REASON_DATE_UNAVAILABLE: Final[str] = 'date_unavailable'
LOST_REASON_NO_ANSWER: Final[str] = 'no_answer'
LOST_REASON_COMPETITOR: Final[str] = 'competitor'
LOST_REASON_CHANGED_MIND: Final[str] = 'changed_mind'
LOST_REASON_OTHER_BRANCH: Final[str] = 'other_branch'
LOST_REASON_LATER: Final[str] = 'later'
LOST_REASON_OTHER: Final[str] = 'other'

# Canonical sales reasons. Legacy values below remain accepted so existing
# requests and historical rows remain readable.
LOST_REASON_PRICE: Final[str] = 'price'
LOST_REASON_NO_RESPONSE: Final[str] = 'no_response'
LOST_REASON_CHOSE_COMPETITOR: Final[str] = 'chose_competitor'
LOST_REASON_CHANGED_PLANS: Final[str] = 'changed_plans'
LOST_REASON_DUPLICATE: Final[str] = 'duplicate'

LOST_REASONS: frozenset[str] = frozenset(
    {
        LOST_REASON_TOO_EXPENSIVE,
        LOST_REASON_DATE_UNAVAILABLE,
        LOST_REASON_NO_ANSWER,
        LOST_REASON_COMPETITOR,
        LOST_REASON_CHANGED_MIND,
        LOST_REASON_OTHER_BRANCH,
        LOST_REASON_LATER,
        LOST_REASON_OTHER,
        LOST_REASON_PRICE,
        LOST_REASON_NO_RESPONSE,
        LOST_REASON_CHOSE_COMPETITOR,
        LOST_REASON_CHANGED_PLANS,
        LOST_REASON_DUPLICATE,
    }
)

ACTIVE_BIRTHDAY_LEAD_STATUSES: frozenset[str] = frozenset(
    {
        'new',
        'contacted',
        'qualified',
        'booked',
        'paid',
        # Historical statuses remain active until explicitly terminal.
        'in_progress',
        'confirmed',
    }
)

TERMINAL_BIRTHDAY_LEAD_STATUSES: frozenset[str] = frozenset(
    {'completed', 'lost', 'cancelled', 'closed'}
)
