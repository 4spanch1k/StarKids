# Star Kids Shymkent

Monorepo foundation for the Star Kids Shymkent mobile product.

## Workspace

- `mobile_app/`: Flutter client for parents
- `admin_panel/`: Vue 3 backoffice for operators
- `backend/`: FastAPI API and business modules
- `docs/`: product, architecture, and implementation rules

## Product direction

The product is a retention-first mobile MVP, not a brochure app.
Priority flows:

- branch discovery
- prices and rules
- birthday package discovery
- request submission
- promotions
- push-ready return paths

## Implementation order

1. Backend foundation and admin auth
2. Admin CRUD for branches, packages, tariffs, promotions, and leads
3. Mobile shell and branch selection slice
4. Mobile content slices for home, branch details, gallery, and promotions
5. Birthday request flow
6. Push registration and profile hardening

## Conventions

- Build by vertical slices
- Keep UI, state, data access, and integrations separate
- Avoid speculative abstractions
- Do not introduce loyalty, payments, or heavy booking in MVP
- Do not use Tailwind

See [docs/star-kids-project-foundation.md](/Users/aspanch1k/Desktop/StarKids/docs/star-kids-project-foundation.md) and
[docs/shared-conventions.md](/Users/aspanch1k/Desktop/StarKids/docs/shared-conventions.md).

