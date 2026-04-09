from typing import Final, Literal

LeadType = Literal['birthday_request', 'contact']
LeadStatus = Literal['new', 'in_progress', 'closed']

LEAD_TYPE_BIRTHDAY_REQUEST: Final[LeadType] = 'birthday_request'
LEAD_TYPE_CONTACT: Final[LeadType] = 'contact'

LEAD_STATUS_NEW: Final[LeadStatus] = 'new'
LEAD_STATUS_IN_PROGRESS: Final[LeadStatus] = 'in_progress'
LEAD_STATUS_CLOSED: Final[LeadStatus] = 'closed'
