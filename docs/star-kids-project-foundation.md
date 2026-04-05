# Star Kids Shymkent Project Foundation

## Status

This document is the working source of truth for the Star Kids Shymkent product foundation.
It captures the fixed product direction, scope boundaries, stack decisions, architecture rules,
and delivery order for future work.

## 1. Product Thesis

Star Kids is not a brochure app.
The mobile product exists to increase repeat visits, simplify birthday requests,
support promotions, and create a direct retention channel with parents.

The app must solve real recurring actions:

- check branch details fast
- view prices and rules
- submit a birthday request
- discover promotions
- return through push notifications and repeat-use flows

If a feature does not support retention, lead generation, or operational convenience,
it should not enter MVP by default.

## 2. Fixed Stack

The stack is fixed unless a future decision document explicitly replaces it.

- Mobile app: Flutter + Dart
- Admin panel: Vue 3 + TypeScript + Vite + Pinia + Vue Router + SCSS/CSS Modules
- Backend API: Python + FastAPI
- Database: PostgreSQL
- ORM and migrations: SQLAlchemy 2 + Alembic
- Validation: Pydantic v2
- Push: Firebase Cloud Messaging
- File storage: S3-compatible storage
- Background jobs: Celery or Dramatiq + Redis
- Monitoring: Sentry + structured logs + health checks

## 3. Product Principles

### 3.1 Business principles

- Build for retention first, not for decorative presence in app stores.
- Birthday requests are the primary monetization flow in MVP.
- Branch discovery and fast contact must be available in under a minute.
- Promotions and push communication must be useful, not noisy.
- Guest-friendly entry is acceptable in MVP if it reduces first-use friction.

### 3.2 MVP principles

- Keep the first release lean, fast, and operationally useful.
- Prefer simple request flows over complex booking engines.
- Build admin operations early so customer requests are processed reliably.
- Avoid heavy profile, loyalty, wallet, referral, or gamification systems in P0.
- Ship vertical slices instead of horizontal technical layers with no user value.

### 3.3 UX principles

- Mobile-first always.
- Parents must understand what to do on each screen immediately.
- Keep navigation shallow and action-oriented.
- Every feature must define loading, empty, error, and success states.
- Prioritize fast path actions: call, WhatsApp, request submission, branch selection.

## 4. Core User Scenarios

### 4.1 Check the park quickly

In 30 to 60 seconds the user should be able to:

- choose a branch
- see address, schedule, gallery, and pricing basics
- contact the branch

### 4.2 Organize a birthday

The user should be able to:

- open the birthdays section
- review packages
- select branch and approximate date
- submit a request with preferences

### 4.3 Respond to a promotion

The user receives a push notification, opens the app, sees the promotion,
and takes a clear action.

### 4.4 Return to the app later

The user comes back for:

- promotions
- repeat requests
- branch information
- future loyalty or bonus mechanics

## 5. MVP Scope

### 5.1 P0 launch scope

- splash and onboarding
- branch selection
- home
- branch details
- birthdays
- birthday package details
- prices and rules
- promotions
- gallery
- contacts and map links
- request forms
- WhatsApp and call actions
- backend APIs for mobile
- admin auth
- lead inbox
- CRUD for branches, packages, tariffs, promotions, gallery, content, FAQ
- push foundation
- analytics and crash reporting

### 5.2 P1 next scope

- phone auth
- profile
- request history
- notification center
- event announcements
- group visits
- master classes
- deposit request flow

### 5.3 P2 later scope

- loyalty
- gift certificates
- online payments
- memberships
- booking calendar
- segmentation
- personalization
- referral program

## 6. Non-Goals for MVP

Do not add these to P0 unless requirements change explicitly:

- full loyalty system
- wallet or bonus ledger
- real-time slot booking engine
- heavy in-app staff mode
- complex chat module
- marketplace or store
- overloaded child-style game UI

## 7. Information Architecture

### 7.1 Primary mobile screens

1. Splash
2. Onboarding
3. Branch selection
4. Home
5. Branch details
6. Birthdays
7. Birthday package details
8. Prices and rules
9. Promotions
10. Gallery
11. Contacts and map
12. Request form
13. Profile
14. Notifications center
15. About and legal

### 7.2 Future screens

- loyalty and bonuses
- gift cards
- memberships
- booking calendar
- payment and deposit
- event schedule
- group visits
- master classes
- reviews
- refer a friend

## 8. Architecture Boundaries

### 8.1 Mobile app

Use Flutter as a dedicated parent-facing client.
The app owns onboarding, branch browsing, content consumption, requests,
profile basics, and notification UX.

Target structure:

```text
mobile_app/
  lib/
    app/
      router/
      theme/
      config/
      di/
    core/
      api/
      storage/
      errors/
      utils/
      widgets/
    features/
      onboarding/
      auth/
      home/
      branches/
      birthdays/
      promotions/
      gallery/
      profile/
      requests/
      notifications/
    shared/
      models/
      constants/
      services/
```

Rules:

- feature-first structure
- keep UI, state, and data boundaries explicit
- keep shared networking and storage abstractions in `core` or `shared`
- avoid giant screen folders with mixed responsibilities

### 8.2 Admin panel

Use Vue 3 only for the operational backoffice.
The admin panel owns requests, content, branches, packages, tariffs,
promotions, customers, campaigns, users, and audit review.

Target structure:

```text
admin_panel/
  src/
    app/
      router/
      providers/
      layouts/
      styles/
    pages/
      dashboard/
      leads/
      branches/
      birthday-packages/
      tariffs/
      promotions/
      content/
      faq/
      gallery/
      customers/
      settings/
      users/
    widgets/
    features/
    entities/
    shared/
      api/
      ui/
      lib/
      config/
      types/
```

Rules:

- keep admin separate from mobile
- page composition lives in `pages`
- business actions live in `features`
- domain models live in `entities`
- infra code and shared UI live in `shared`
- no Tailwind
- use Composition API, `script setup`, and clean service boundaries

### 8.3 Backend

FastAPI is the single API center for mobile, admin, auth, notifications,
lead processing, integrations, and content delivery.

Target structure:

```text
backend/
  app/
    main.py
    core/
      config/
      security/
      logging/
      database/
      storage/
      tasks/
      exceptions/
    modules/
      mobile_auth/
      customers/
      home/
      branches/
      birthdays/
      tariffs/
      promotions/
      gallery/
      leads/
      notifications/
      content/
      admin_auth/
      admin_users/
      push_campaigns/
      audit/
    db/
      models/
      repositories/
    services/
    integrations/
      crm/
      whatsapp/
      push/
      payments/
      sms/
    tests/
```

Rules:

- route handlers stay thin
- business logic goes to services or module-level use cases
- persistence is explicit
- auth, notifications, logging, storage, and config stay centralized

## 9. Core Domain Model

### 9.1 Core content and branch entities

- branches
- branch_hours
- branch_features
- media_files
- gallery_items

### 9.2 Commercial entities

- visit_tariffs
- birthday_packages
- birthday_package_items
- extra_services
- promotions
- events

### 9.3 Customer entities

- customers
- customer_devices
- customer_sessions
- otp_codes

### 9.4 Lead entities

- lead_requests
- birthday_requests
- group_requests
- callback_requests

### 9.5 Content and admin entities

- app_banners
- app_sections
- faq_items
- legal_pages
- users
- roles
- user_roles
- audit_logs
- notification_campaigns
- push_deliveries

## 10. API Direction

### 10.1 Public mobile modules

- auth
- profile
- home
- branches
- birthdays
- tariffs
- promotions
- gallery
- contacts
- leads
- notifications
- settings

### 10.2 Admin modules

- admin_auth
- dashboard
- branches
- birthday_packages
- tariffs
- promotions
- app_content
- gallery
- faq
- leads
- customers
- push_campaigns
- users
- roles
- audit

### 10.3 Example mobile routes

- `POST /api/v1/mobile/auth/request-otp`
- `POST /api/v1/mobile/auth/verify-otp`
- `GET /api/v1/mobile/home`
- `GET /api/v1/mobile/branches`
- `GET /api/v1/mobile/birthday-packages`
- `GET /api/v1/mobile/promotions`
- `POST /api/v1/mobile/leads/contact`
- `POST /api/v1/mobile/leads/birthday`
- `GET /api/v1/mobile/me`
- `POST /api/v1/mobile/me/push-token`
- `GET /api/v1/mobile/notifications`

### 10.4 Example admin routes

- `POST /api/v1/admin/auth/login`
- `GET /api/v1/admin/dashboard/summary`
- CRUD `/api/v1/admin/branches`
- CRUD `/api/v1/admin/birthday-packages`
- CRUD `/api/v1/admin/tariffs`
- CRUD `/api/v1/admin/promotions`
- CRUD `/api/v1/admin/gallery`
- CRUD `/api/v1/admin/faq`
- `GET /api/v1/admin/leads`
- `PATCH /api/v1/admin/leads/{id}/status`
- `GET /api/v1/admin/customers`
- `POST /api/v1/admin/push-campaigns`
- `GET /api/v1/admin/audit-logs`

## 11. Delivery Roadmap

### 11.1 Discovery

Produce:

- mobile product brief
- retention hypothesis
- MVP scope confirmation
- content inventory

### 11.2 UX and UI

Design:

- navigation map
- onboarding flow
- home hierarchy
- birthday request flow
- request form flow
- profile flow
- notification UX
- mobile design system

### 11.3 Backend foundation

- FastAPI scaffold
- PostgreSQL setup
- migrations
- auth foundation
- content modules
- lead modules
- push infrastructure
- admin auth

### 11.4 Admin foundation

- branches and content CRUD
- packages and tariffs CRUD
- lead inbox
- promotions CRUD
- push campaign base

### 11.5 Mobile MVP slices

Slice 1:

- app shell
- theme
- navigation
- branch selection

Slice 2:

- home
- branch details
- static content
- gallery

Slice 3:

- birthdays
- package details
- birthday request flow

Slice 4:

- promotions
- pricing and rules
- contacts and maps

Slice 5:

- auth or guest-flow hardening
- profile
- push token registration
- notifications center

### 11.6 QA and launch

Validate:

- Android and iOS behavior
- push delivery
- OTP flow
- request flows
- admin processing
- analytics events
- crash reporting
- offline edge cases
- media rendering

Then:

- internal beta
- content freeze
- store assets
- release submission
- production environment checks
- monitoring checks

## 12. Risks and Guardrails

- App install without repeat value: solve with promotions, birthdays, convenience, and push utility.
- Low retention after first launch: solve with clear return triggers and useful content cadence.
- Overbuilt technical scope: solve with lean MVP and vertical slices.
- Slow lead processing: solve by building admin lead operations early.
- Store delay risk: solve by preparing legal, privacy, assets, and release metadata in advance.

## 13. Working Rules For Future Tasks

Use these rules in future implementation unless explicitly changed:

- treat this app as a customer retention product
- prefer vertical slices over broad platform work
- do not introduce loyalty or payment systems before core usage data exists
- keep mobile flows parent-focused and action-focused
- keep admin web-only
- keep architecture clean and modular
- avoid speculative abstractions
- keep every feature small enough to evolve safely
- require loading, empty, error, and success states for user-facing features

## 14. Immediate Default Priorities

When no other priority is specified, work in this order:

1. confirm and shape the MVP around repeat-use value
2. define navigation and screen responsibilities
3. scaffold backend and admin foundations
4. implement mobile shell
5. deliver branches slice
6. deliver birthdays slice
7. deliver leads and notifications
8. harden profile and auth
9. validate on real devices
10. launch beta before expanding scope
