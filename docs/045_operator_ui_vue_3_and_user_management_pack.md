# Operator UI (Vue 3) + User Management + Full System Walkthrough Pack

This pack turns the backend platform into a usable operations product.

It covers:
- Vue 3 container architecture
- auth and user management
- admin and ops application structure
- page map for every current domain
- API integration conventions
- role-aware navigation
- manual test walkthrough for every working module
- Playwright coverage plan
- seeded admin account

---

# 1. UI target state

Build a **single Vue 3 frontend workspace** with two role-aware shells:

- `web-admin`: configuration, governance, reference data, user management
- `web-ops`: runtime monitoring, orders, risk, incidents, reconciliation

You can keep them as separate apps in the repo for now, but they should share:
- auth logic
- API client layer
- route guards
- layouts
- table/filter components
- badges and workflow UI

Longer term, these can become a single app with role-based navigation.

---

# 2. Seeded user model for testing

Add these seeded users:

## Super admin
- username: `admin`
- email: `admin@example.com`
- password: `admin`
- roles: `super_admin`

## Operations user
- username: `ops`
- email: `ops@example.com`
- password: `ops`
- roles: `operations`

## Risk user
- username: `risk`
- email: `risk@example.com`
- password: `risk`
- roles: `risk_officer`

## Compliance user
- username: `compliance`
- email: `compliance@example.com`
- password: `compliance`
- roles: `compliance_officer`

For immediate implementation, `admin/admin` is the critical one.

---

# 3. Recommended frontend repo structure

```text
apps/
├─ web-admin/
│  └─ src/
│     ├─ app/
│     ├─ api/
│     ├─ components/
│     ├─ composables/
│     ├─ layouts/
│     ├─ router/
│     ├─ stores/
│     ├─ modules/
│     │  ├─ auth/
│     │  ├─ dashboard/
│     │  ├─ users/
│     │  ├─ roles/
│     │  ├─ markets/
│     │  ├─ venues/
│     │  ├─ instruments/
│     │  ├─ strategies/
│     │  ├─ deployments/
│     │  ├─ features/
│     │  ├─ datasets/
│     │  ├─ workflows/
│     │  ├─ incidents/
│     │  ├─ compliance/
│     │  └─ audit/
│     └─ views/
│
└─ web-ops/
   └─ src/
      ├─ app/
      ├─ api/
      ├─ components/
      ├─ composables/
      ├─ layouts/
      ├─ router/
      ├─ stores/
      ├─ modules/
      │  ├─ auth/
      │  ├─ dashboard/
      │  ├─ runtime-health/
      │  ├─ signals/
      │  ├─ targets/
      │  ├─ orders/
      │  ├─ executions/
      │  ├─ positions/
      │  ├─ risk/
      │  ├─ breaches/
      │  ├─ kill-switches/
      │  ├─ reconciliation/
      │  ├─ market-data/
      │  ├─ features/
      │  └─ incidents/
      └─ views/
```

Shared UI should live in:

```text
packages/ui-kit/
packages/frontend-auth/
packages/frontend-api/
packages/frontend-utils/
```

---

# 4. Core UI framework decisions

## Recommended stack
- Vue 3
- TypeScript
- Vue Router
- Pinia
- Axios
- Tailwind CSS
- VueUse
- TanStack Table for strong grids later
- Playwright for e2e

## Why
This gives you:
- clean modular forms and pages
- reusable data grids
- proper route guards
- maintainable state
- testable flows

---

# 5. Authentication and session flow

## Login flow
1. user enters email or username + password
2. frontend calls identity login endpoint
3. token + roles + permissions saved in auth store
4. router redirects based on role

## Auth store should keep
- access token
- user profile
- roles
- permissions
- isAuthenticated

## Route guards
Each route should define:
- requiresAuth
- requiredRoles or requiredPermissions

If unauthorized:
- redirect to login
or
- show forbidden page

---

# 6. API client structure

Create one API client layer per domain.

```text
src/api/
├─ http.ts
├─ auth.ts
├─ users.ts
├─ markets.ts
├─ instruments.ts
├─ strategies.ts
├─ runtime.ts
├─ signals.ts
├─ targets.ts
├─ orders.ts
├─ execution.ts
├─ positions.ts
├─ risk.ts
├─ reconciliation.ts
├─ workflows.ts
├─ incidents.ts
├─ compliance.ts
└─ audit.ts
```

## http client responsibilities
- attach bearer token
- attach correlation id
- normalize errors
- redirect on 401 if needed

---

# 7. Layout design

## Admin layout
Left nav sections:
- Dashboard
- Users
- Roles
- Markets
- Instruments
- Strategies
- Deployments
- Features
- Datasets
- Workflows
- Incidents
- Compliance Exports
- Audit

## Ops layout
Left nav sections:
- Dashboard
- Runtime Health
- Signals
- Targets
- Orders
- Executions
- Positions
- Risk
- Breaches
- Kill Switches
- Reconciliation
- Market Data
- Features
- Incidents

Top bar should show:
- current user
- role badges
- environment badge
- logout

---

# 8. Required pages for current working backend

## 8.1 Auth
- Login page
- Forbidden page

## 8.2 Admin dashboard
Show quick counts:
- markets
- instruments
- strategies
- workflows
- incidents
- exports

## 8.3 Users
For now:
- list users
- user detail
- role assignments later

## 8.4 Markets
- list markets
- detail drawer later

## 8.5 Instruments
- list instruments
- filter by asset class later

## 8.6 Strategies
- list strategies
- deployment summary later

## 8.7 Strategy runtime health
- list heartbeats
- status badges

## 8.8 Signals
- list latest signals
- signal detail later

## 8.9 Portfolio targets
- list targets
- source signal ids visible

## 8.10 Orders
- list orders
- submit order form
- order detail with state history

## 8.11 Executions
- execution quality metrics page
- broker order state history later

## 8.12 Positions
- list positions

## 8.13 Risk
- breaches page
- kill switches page
- drawdown tracker page

## 8.14 Reconciliation
- list runs
- list issues

## 8.15 Market data
- normalized candles page

## 8.16 Features
- feature definitions page
- feature values page
- backfill trigger form

## 8.17 Datasets
- list dataset versions
- create dataset version form

## 8.18 Replay
- replay jobs page
- create replay job form

## 8.19 Workflows
- list workflows
- start workflow run form

## 8.20 Incidents
- incidents list
- incident events later

## 8.21 Compliance
- export requests page

## 8.22 Audit
- audit list

---

# 9. Strong page design conventions

Every domain page should have the same pattern:

## Header row
- page title
- short description
- primary action button where relevant

## Filter bar
- search input
- status filter
- date range filter later

## Data grid
Columns should be sortable where possible.

## Right drawer or detail page
Use for record details instead of dumping JSON inline.

## Empty state
Say what to do next.

---

# 10. Suggested component library inside ui-kit

Create these reusable components first:
- `AppShell`
- `SideNav`
- `TopBar`
- `PageHeader`
- `StatCard`
- `DataTable`
- `StatusBadge`
- `EmptyState`
- `DetailDrawer`
- `ConfirmDialog`
- `JsonPreview`
- `FormField`
- `FormSection`

These will dramatically speed up page creation.

---

# 11. Pinia store map

## `authStore`
- token
- user
- roles
- permissions
- login/logout

## `uiStore`
- side nav state
- theme later
- current environment badge

## Optional domain stores
Keep them minimal at first. Prefer composables + page-local fetching until complexity grows.

---

# 12. Role-aware navigation rules

## super_admin
Can see everything.

## operations
Can see:
- runtime health
- signals
- targets
- orders
- executions
- positions
- incidents
- reconciliation

## risk_officer
Can see:
- risk
- breaches
- kill switches
- drawdown
- orders
- positions
- incidents

## compliance_officer
Can see:
- workflows
- incidents
- compliance exports
- audit

For now, simplest path:
- `admin` sees all
- everyone else can be added after the admin flow works

---

# 13. API integration rules

## Token handling
- add token to `Authorization: Bearer ...`

## Correlation ids
- generate one per request in axios interceptor

## Error handling
Normalize backend errors into:
- title
- message
- code
- correlation id

Show correlation id in the UI for debugging.

---

# 14. Minimum backend changes needed for user management UI

To fully support UI user management, add endpoints later:
- `GET /api/users`
- `GET /api/users/:id`
- `POST /api/users`
- `PATCH /api/users/:id`
- `GET /api/roles`
- `POST /api/users/:id/roles`

For now, login is enough to start the UI.

---

# 15. Full manual walkthrough by domain package

This is the testing walkthrough you asked for.

## 15.1 Identity / login
1. open `web-admin`
2. login with `admin@example.com` / `admin`
3. verify redirect to dashboard or markets page
4. refresh page and confirm session persists if implemented

Expected:
- login succeeds
- token stored
- role-aware nav visible

## 15.2 Markets
1. open Markets page
2. verify seeded Forex and Crypto rows

Expected:
- 2 market rows visible
- no console errors

## 15.3 Instruments
1. open Instruments page
2. verify seeded `EURUSD`, `GBPUSD`, `USDJPY`, `XAUUSD`

Expected:
- rows render correctly
- asset class/base/quote visible

## 15.4 Strategies
1. open Strategies page
2. verify seeded strategies show

Expected:
- `fx_ma_cross`
- `fx_mean_rev`

## 15.5 Market data
1. run data feature smoke script or ingest a demo candle
2. open Market Data page
3. verify normalized candle row appears

Expected:
- latest candle visible
- values look correct

## 15.6 Features
1. click seed feature definitions or call endpoint
2. open Feature Definitions page
3. verify `SMA_20` and `SMA_50`
4. trigger backfill if enough candles exist
5. open Feature Values page

Expected:
- definitions visible
- values appear after backfill

## 15.7 Runtime health
1. run sample runtime endpoint
2. open Runtime Health page

Expected:
- heartbeat row visible
- status = healthy

## 15.8 Signals
1. after sample runtime run, open Signals page

Expected:
- generated signal visible
- direction/strength/confidence shown

## 15.9 Portfolio targets
1. after signal processing, open Targets page

Expected:
- target row visible
- target quantity and delta visible

## 15.10 Orders
1. open Orders page in ops UI
2. use instrument id + venue id from seeded data
3. submit integrated order
4. open order detail

Expected:
- order accepted or filled depending on current mode
- state history visible
- correlation id shown

## 15.11 Executions
1. open Execution Quality page
2. verify metrics rows exist after order execution

Expected:
- slippage bps row visible
- fee amount visible

## 15.12 Positions
1. open Positions page
2. verify submitted order changed position

Expected:
- correct instrument row
- net quantity updated
- avg price visible

## 15.13 Risk / breaches
1. manually create kill switch
2. submit another order
3. inspect breaches page

Expected:
- kill switch visible
- risk reject occurs
- breach row visible when rule fails

## 15.14 Drawdown trackers
1. call drawdown endpoint manually
2. open Drawdown page

Expected:
- tracker row visible

## 15.15 Reconciliation
1. create reconciliation run
2. create issue manually
3. open Reconciliation Runs and Issues pages

Expected:
- run row visible
- issue row visible

## 15.16 Workflows
1. create a workflow definition
2. start a workflow run
3. open Workflows page

Expected:
- workflow row visible
- run row visible

## 15.17 Incidents
1. once incident endpoints are added or records seeded, open Incidents page

Expected:
- incident rows visible
- severity/status visible

## 15.18 Compliance exports
1. create compliance export request
2. open Compliance Exports page

Expected:
- export row visible
- status shown

## 15.19 Audit
1. submit an order and other actions
2. open Audit page

Expected:
- audit rows visible
- resource type/event type visible

---

# 16. Playwright end-to-end coverage plan

Create these e2e specs first.

## `auth.spec.ts`
- login success
- login failure
- logout

## `admin-reference-data.spec.ts`
- markets list renders
- instruments list renders
- strategies list renders

## `ops-order-flow.spec.ts`
- open orders page
- submit order
- assert success response shown
- go to positions page
- assert position updated

## `risk-controls.spec.ts`
- create kill switch via API or UI
- attempt order submit
- assert reject state

## `data-feature-flow.spec.ts`
- ingest candle by API helper
- view candle page
- seed features
- view feature definitions

## `workflow-compliance.spec.ts`
- create workflow
- start run
- create export
- assert rows visible

---

# 17. Recommended UI build order

Do not build every page at once.

## Phase A: core shell
- auth store
- login page
- admin layout
- ops layout
- route guards

## Phase B: reference data + audit
- markets
- instruments
- strategies
- audit

## Phase C: operations workflow
- orders
- positions
- execution quality
- risk pages

## Phase D: data/research pages
- market data
- features
- datasets
- replay

## Phase E: governance pages
- workflows
- incidents
- compliance exports

## Phase F: detail pages + polish
- order detail page
- signal detail page
- target detail page
- reconciliation issue detail page

---

# 18. Recommended initial route map

## Admin app
- `/login`
- `/dashboard`
- `/users`
- `/markets`
- `/instruments`
- `/strategies`
- `/features`
- `/datasets`
- `/workflows`
- `/incidents`
- `/compliance/exports`
- `/audit`

## Ops app
- `/login`
- `/dashboard`
- `/runtime-health`
- `/signals`
- `/targets`
- `/orders`
- `/orders/:id`
- `/executions/quality`
- `/positions`
- `/risk/breaches`
- `/risk/kill-switches`
- `/risk/drawdown`
- `/reconciliation/runs`
- `/reconciliation/issues`
- `/market-data/candles`
- `/features/definitions`
- `/features/values`

---

# 19. Minimum useful dashboard widgets

## Admin dashboard
- total markets
- total instruments
- total strategies
- total workflows
- open incidents
- pending exports

## Ops dashboard
- latest heartbeats
- latest signals
- latest targets
- latest orders
- latest breaches
- active kill switches

---

# 20. Backend alignment checklist before UI build

Before you fully wire UI pages, confirm these endpoints exist and return stable JSON:
- auth login
- markets list
- instruments list
- strategies list
- audit list
- orders list + submit + detail
- positions list
- risk breaches / kill switches / drawdown
- execution quality metrics
- workflow list / create / run
- compliance export list / create
- candles list / ingest
- feature definitions / values / backfill
- replay jobs
- signals list
- targets list
- runtime sample / heartbeats list

---

# 21. What I recommend you build next in code

The strongest practical next artifact is:

## **Vue 3 operator UI scaffold package**

That should include real code for:
- shared auth store
- route guards
- layouts
- reusable data table
- login flow
- admin reference data pages
- ops orders + positions pages
- Playwright starter tests

That will make the whole platform visible and manually testable end to end.

