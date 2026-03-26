# Stage-by-Stage Defect and Fix Tracker

Use this tracker while integrating the repo so you always know:
- what stage you are in
- what is broken
- what blocks the next stage
- what “fixed” means before moving on

---

# 1. Overall control sheet

## Project status
- Current Stage:
- Current Branch:
- Current Commit:
- Owner:
- Last Updated:

## Global rules
- Do not move to the next stage until the current stage exit criteria are met.
- Fix highest-severity blockers first.
- Retest the full happy path after every major fix.
- Log every defect with exact reproduction steps.

---

# 2. Defect severity rules

## Critical
- platform cannot start
- migrations fail
- login impossible
- orders cannot be submitted at all
- risk or execution unsafe/bypassed

## High
- a core module works incorrectly
- positions do not update
- audit trail missing for core actions
- UI core pages unusable

## Medium
- partial functionality
- event-driven flow incomplete but synchronous path works
- dashboards/pages load with missing data or weak UX

## Low
- cosmetic issues
- copy/layout issues
- minor non-blocking inconsistencies

---

# 3. Stage tracker template

Use this template for every stage.

## Stage
- Name:
- Goal:
- Depends On:
- Owner:
- Status: Not Started / In Progress / Blocked / Passed

## Entry criteria
-

## Verification steps
-

## Exit criteria
-

## Defects found
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|

## Fix log
| Fix ID | Defect ID | Change Made | Files Touched | Retest Result |
|---|---|---|---|---|

---

# 4. Stage 1 tracker — Core vertical slice

## Goal
Get the first complete synchronous trading path working.

## Entry criteria
- repo exists
- bootstrap applied
- docker available

## Verification steps
- run stack
- run migrations
- run seed
- test login API
- test markets/instruments/strategies APIs
- submit one order
- verify one position row
- verify audit rows exist

## Exit criteria
- login works
- seeded data visible
- one order reaches filled state
- one position updates
- audit records order lifecycle

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S1-001 | Service fails to boot | Critical |  | Docker/config/imports | Yes |
| S1-002 | Migration failure | Critical |  | SQL/schema | Yes |
| S1-003 | Seed failure | High |  | Seed/data/password hash | Yes |
| S1-004 | Login 401 with seeded admin | Critical |  | Identity/seed/auth | Yes |
| S1-005 | Order submit 500 | Critical |  | Order-service integration | Yes |
| S1-006 | Position not updating | High |  | Position-service | Yes |
| S1-007 | Audit rows missing | High |  | Audit integration | Yes |

## Fix priorities
1. boot/migration errors
2. login
3. order submit
4. positions
5. audit

---

# 5. Stage 2 tracker — Hardening

## Goal
Add safe auth, state history, correlation IDs, and idempotency.

## Entry criteria
- Stage 1 passed

## Verification steps
- protected endpoints reject missing token
- valid token works
- order detail returns state history
- correlation ID visible in responses
- same idempotency key does not duplicate an order

## Exit criteria
- JWT protection works
- internal auth works for service calls
- state history visible
- duplicate submit prevented

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S2-001 | Protected routes allow anonymous access | Critical |  | Auth guard | Yes |
| S2-002 | Valid token rejected | High |  | JWT config/issuer | Yes |
| S2-003 | Order history empty | High |  | State history persistence | No |
| S2-004 | Correlation ID missing | Medium |  | Middleware/interceptors | No |
| S2-005 | Idempotency duplicates order | High |  | DB logic/order submit | Yes |

## Fix priorities
1. JWT correctness
2. idempotency
3. state history
4. correlation tracing

---

# 6. Stage 3 tracker — Risk controls and execution quality

## Goal
Make core trading safe and measurable.

## Entry criteria
- Stage 2 passed

## Verification steps
- create kill switch
- submit order while active
- verify rejection
- verify breaches list
- submit successful order without kill switch
- verify execution quality row
- create reconciliation run and issue

## Exit criteria
- kill switch blocks new orders
- risk breach path works
- execution quality recorded
- reconciliation endpoints usable

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S3-001 | Kill switch not enforced | Critical |  | Risk-service logic | Yes |
| S3-002 | Breach not recorded | High |  | Risk persistence | No |
| S3-003 | Execution quality metrics absent | High |  | Execution-service | No |
| S3-004 | Reconciliation run not created | Medium |  | Reconciliation-service | No |

## Fix priorities
1. kill switch enforcement
2. successful execution metrics
3. reconciliation persistence

---

# 7. Stage 4 tracker — Operator UI core

## Goal
Make the platform operable through the UI.

## Entry criteria
- Stage 1 and Stage 3 stable enough for manual use

## Verification steps
- admin login page works
- ops login page works
- admin reference pages render
- ops orders page submits order
- positions page updates
- risk pages render

## Exit criteria
- both UIs usable
- one full happy path can be executed from UI

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S4-001 | UI cannot log in | Critical |  | Frontend auth/api | Yes |
| S4-002 | Reference pages blank | High |  | API wiring/CORS | Yes |
| S4-003 | Order form submits but backend error hidden | High |  | UI error handling | Yes |
| S4-004 | Detail route broken | Medium |  | Router/API mismatch | No |
| S4-005 | Kill switch UI action fails | Medium |  | Risk endpoint/UI | No |

## Fix priorities
1. login
2. reference data pages
3. order page
4. positions/risk pages
5. detail pages

---

# 8. Stage 5 tracker — Manual QA execution

## Goal
Establish the real state of the system with evidence.

## Entry criteria
- UI core usable
- main APIs stable enough to test

## Verification steps
- execute QA checklist in order
- mark pass/fail/blocked
- open defects for every failure

## Exit criteria
- every checklist item has a result
- blockers are clearly identified
- no unknown system areas remain

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S5-001 | Test blocked by missing seed data | Medium |  | Seed/process | Yes |
| S5-002 | Runtime/signals/targets partially wired | Medium |  | Event/runtime path | No |
| S5-003 | Governance pages exist but backend partial | Medium |  | Workflow/compliance | No |

## Fix priorities
1. unblock blocked tests
2. confirm core pass path
3. document partial scaffolds honestly

---

# 9. Stage 6 tracker — Playwright automation

## Goal
Turn the happy path and key regressions into repeatable automated tests.

## Entry criteria
- manual QA core path passes
- venue lookup endpoint available

## Verification steps
- run smoke suite
- run admin auth tests
- run admin reference data tests
- run ops auth tests
- run order flow test

## Exit criteria
- smoke suite green
- core UI tests green
- CI workflow can execute suite

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S6-001 | Smoke tests fail on service startup timing | Medium |  | CI/startup sequencing | No |
| S6-002 | UI selectors unstable | Medium |  | Frontend markup | No |
| S6-003 | Order flow flaky | High |  | Async timing/backend state | Yes |
| S6-004 | CI missing system dependency | Medium |  | GitHub Actions config | No |

## Fix priorities
1. smoke stability
2. order flow reliability
3. CI environment fixes
4. selector hardening

---

# 10. Stage 7 tracker — Event-driven pipeline

## Goal
Move from direct orchestration toward reliable async processing.

## Entry criteria
- synchronous happy path already stable

## Verification steps
- order submit writes outbox event
- risk consumer processes order-created
- execution consumer processes risk-completed
- position consumer processes fill-recorded
- duplicate events do not reapply

## Exit criteria
- one order can complete through async path
- processed-events protection works

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S7-001 | Outbox writes but publisher not running | High |  | Worker/orchestration | Yes |
| S7-002 | Consumer runs twice | High |  | Idempotency/inbox logic | Yes |
| S7-003 | Async path updates order but not position | High |  | Consumer chain gap | Yes |
| S7-004 | Event payload schema mismatch | High |  | Contract/versioning | Yes |

## Fix priorities
1. payload contracts
2. consumer idempotency
3. end-to-end async completion

---

# 11. Stage 8 tracker — Strategy runtime, signals, targets

## Goal
Prove research/runtime outputs can flow into portfolio intent.

## Entry criteria
- market data and feature base exists
- Stage 7 at least partially stable if event-driven path is used

## Verification steps
- run sample runtime
- verify heartbeat
- verify signal persistence
- verify target generation

## Exit criteria
- one sample candle leads to one visible signal
- signal leads to target or the exact missing link is isolated

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S8-001 | Runtime emits but signal not stored | High |  | Runtime/output path | Yes |
| S8-002 | Signal stored but no target generated | High |  | Portfolio consumer | Yes |
| S8-003 | Heartbeat missing | Medium |  | Runtime persistence | No |

## Fix priorities
1. signal persistence
2. target generation
3. heartbeat visibility

---

# 12. Stage 9 tracker — Market data, features, datasets, replay

## Goal
Stabilize the research substrate.

## Entry criteria
- base services start

## Verification steps
- ingest demo candles
- verify normalized candles
- seed features
- compute feature values with enough warmup data
- create dataset version
- create replay job

## Exit criteria
- market data persists correctly
- feature definitions and at least one feature value exist
- dataset and replay APIs operate

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S9-001 | Candle ingest succeeds but not queryable | High |  | Persistence/model | Yes |
| S9-002 | Feature values never appear due to insufficient warmup | Low |  | Test data design | No |
| S9-003 | Replay job created but no worker exists | Medium |  | Expected scaffold gap | No |

## Fix priorities
1. candle persistence
2. realistic test dataset for feature warmup
3. replay status clarity

---

# 13. Stage 10 tracker — Governance, workflows, compliance

## Goal
Make approval and evidence flows visible and testable.

## Entry criteria
- admin UI stable

## Verification steps
- create workflow
- start workflow run
- create compliance export
- list export
- inspect audit evidence where applicable

## Exit criteria
- governance pages operational
- one workflow run and one export visible from UI

## Common defects to expect
| Defect ID | Summary | Severity | Status | Root Cause Layer | Blocking Next Stage? |
|---|---|---|---|---|---|
| S10-001 | Workflow created but run fails | Medium |  | Workflow-service | No |
| S10-002 | Export created but list broken | Medium |  | Compliance-service/UI | No |
| S10-003 | Incident paths scaffolded but not exposed | Medium |  | Feature completeness | No |

## Fix priorities
1. workflow create/run
2. export create/list
3. incident path completion later

---

# 14. Master blocker board

Use this section to track only items that block progress.

| Blocker ID | Stage | Blocker | Severity | Owner | Started | ETA | Unblocks |
|---|---|---|---|---|---|---|---|
| BLK-001 |  |  |  |  |  |  |  |
| BLK-002 |  |  |  |  |  |  |  |
| BLK-003 |  |  |  |  |  |  |  |

---

# 15. Recommended working rhythm

For each stage:
1. apply stage artifact
2. run only that stage’s verification steps
3. log defects
4. fix highest-severity issue first
5. rerun the same stage
6. only after pass, move forward

This prevents false progress.

---

# 16. Most important success checkpoint

The most important checkpoint in the whole project is still this:

- login works
- seeded reference data visible
- order submit works
- risk evaluates correctly
- execution fills
- position updates
- audit records it
- UI shows it
- smoke automation passes

Once that checkpoint is stable, the rest becomes controlled expansion rather than uncertainty.

