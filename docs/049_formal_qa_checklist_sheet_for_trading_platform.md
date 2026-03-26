# Formal QA Checklist Sheet for the Trading Platform

Use this sheet during manual validation of the current system.

Fill one row per test case.

---

# 1. Test Execution Header

## Session details
- Tester Name:
- Test Date:
- Environment:
- Build/Commit:
- Database Seed Version:
- Notes:

## Result summary
- Total Tests:
- Passed:
- Failed:
- Blocked:
- Not Run:

---

# 2. Status Legend

- **PASS**: worked as expected
- **FAIL**: ran but did not meet expectation
- **BLOCKED**: could not run because of another issue
- **NOT RUN**: intentionally skipped

---

# 3. Defect Severity Legend

- **Critical**: system unusable or trading safety issue
- **High**: core workflow broken
- **Medium**: feature works partially or with incorrect output
- **Low**: cosmetic, minor usability, or non-blocking issue

---

# 4. QA Checklist Table

| ID | Module | Area/Page/API | Test Case | Steps | Expected Result | Actual Result | Status | Defect ID | Severity | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| INF-001 | Infrastructure | Health endpoints | Verify all health endpoints return OK | Open or curl all `/health/live` endpoints | All services return healthy JSON |  |  |  |  |  |
| INF-002 | Infrastructure | Docker services | Verify all required containers are running | Run `docker compose ps` | All expected services are up |  |  |  |  |  |
| DB-001 | Seed | Users | Verify admin user exists | Query DB for `admin@example.com` | Admin row exists |  |  |  |  |  |
| DB-002 | Seed | Markets | Verify seeded markets | Query or call markets API | Forex and Crypto exist |  |  |  |  |  |
| DB-003 | Seed | Venues | Verify seeded venues | Query or call related API/DB | OANDA Demo and Binance Testnet exist |  |  |  |  |  |
| DB-004 | Seed | Instruments | Verify seeded instruments | Query DB or instruments API | EURUSD, GBPUSD, USDJPY, XAUUSD exist |  |  |  |  |  |
| DB-005 | Seed | Strategies | Verify seeded strategies | Query DB or strategies API | fx_ma_cross and fx_mean_rev exist |  |  |  |  |  |
| AUTH-001 | Identity | Login API | Verify admin login works | POST login request with admin credentials | Access token returned |  |  |  |  |  |
| AUTH-002 | Identity | Login API | Verify invalid login fails | POST login with wrong password | 401 or login failure response |  |  |  |  |  |
| ADM-001 | Admin UI | `/login` | Verify admin login page loads | Open admin login page | Form renders correctly |  |  |  |  |  |
| ADM-002 | Admin UI | Login flow | Verify admin login redirects | Submit valid admin credentials | Redirect to dashboard |  |  |  |  |  |
| ADM-003 | Admin UI | Dashboard | Verify dashboard counts load | Open dashboard after login | Counts render without errors |  |  |  |  |  |
| MKT-001 | Reference Data | Markets API | Verify markets API works | GET markets endpoint | Market rows returned |  |  |  |  |  |
| MKT-002 | Admin UI | Markets page | Verify markets page renders | Open markets page | Seeded markets displayed |  |  |  |  |  |
| INS-001 | Reference Data | Instruments API | Verify instruments API works | GET instruments endpoint | Instrument rows returned |  |  |  |  |  |
| INS-002 | Admin UI | Instruments page | Verify instruments page renders | Open instruments page | Seeded instruments displayed |  |  |  |  |  |
| STR-001 | Reference Data | Strategies API | Verify strategies API works | GET strategies endpoint | Strategy rows returned |  |  |  |  |  |
| STR-002 | Admin UI | Strategies page | Verify strategies page renders | Open strategies page | Seeded strategies displayed |  |  |  |  |  |
| AUD-001 | Audit | Audit API | Verify audit endpoint works | GET audit endpoint | Returns list or empty array without error |  |  |  |  |  |
| AUD-002 | Admin UI | Audit page | Verify audit page renders | Open audit page | Audit table loads |  |  |  |  |  |
| MD-001 | Market Data | Ingest candle API | Verify demo candle ingest works | POST ingest-candle payload | Candle accepted and IDs returned |  |  |  |  |  |
| MD-002 | Market Data | Candles API | Verify normalized candle list works | GET candles endpoint | New candle appears |  |  |  |  |  |
| FEAT-001 | Features | Seed definitions | Verify feature definitions can be seeded | POST seed-definitions | Definitions created |  |  |  |  |  |
| FEAT-002 | Features | Definitions API | Verify feature definitions list works | GET definitions endpoint | SMA_20 and SMA_50 visible |  |  |  |  |  |
| FEAT-003 | Features | Backfill API | Verify feature backfill can run | POST backfill with enough candles | Backfill completes successfully |  |  |  |  |  |
| FEAT-004 | Features | Values API | Verify feature values list works | GET values endpoint | Feature values visible when warmup satisfied |  |  |  |  |  |
| DATASET-001 | Dataset | Create dataset version | Verify dataset version creation works | POST dataset payload | Dataset version ID returned |  |  |  |  |  |
| DATASET-002 | Dataset | List dataset versions | Verify dataset versions list works | GET dataset versions | Created row visible |  |  |  |  |  |
| REPLAY-001 | Replay | Create replay job | Verify replay job creation works | POST replay job payload | Job ID returned with queued status |  |  |  |  |  |
| REPLAY-002 | Replay | List replay jobs | Verify replay jobs list works | GET replay jobs | Created replay job visible |  |  |  |  |  |
| RT-001 | Strategy Runtime | Sample runtime API | Verify sample runtime worker runs | POST runtime sample payload | `signals_emitted` returned |  |  |  |  |  |
| RT-002 | Strategy Runtime | Heartbeats | Verify heartbeat entry is written | Check runtime heartbeat source/API/DB | Healthy heartbeat visible |  |  |  |  |  |
| SIG-001 | Signals | Signals API | Verify signals list works | GET signals endpoint after runtime run | Signal rows visible |  |  |  |  |  |
| SIG-002 | Ops UI | Signals page | Verify signals page renders | Open signals page | Signals table loads |  |  |  |  |  |
| TGT-001 | Portfolio | Targets API | Verify portfolio targets list works | GET targets endpoint | Target rows visible if chain is wired |  |  |  |  |  |
| TGT-002 | Ops UI | Targets page | Verify targets page renders | Open targets page | Targets table loads |  |  |  |  |  |
| ORD-001 | Orders | Orders API list | Verify order list works | GET orders endpoint | Existing orders returned |  |  |  |  |  |
| ORD-002 | Orders | Submit order API | Verify order submission works | POST valid order payload | Accepted/filled response returned |  |  |  |  |  |
| ORD-003 | Orders | Order detail API | Verify order detail works | GET order by ID | Detail and state history returned |  |  |  |  |  |
| OPS-001 | Ops UI | `/login` | Verify ops login page loads | Open ops login page | Form renders correctly |  |  |  |  |  |
| OPS-002 | Ops UI | Login flow | Verify ops login works | Submit valid credentials | Redirect to dashboard |  |  |  |  |  |
| OPS-003 | Ops UI | Dashboard | Verify ops dashboard loads | Open dashboard | Counts load without errors |  |  |  |  |  |
| OPS-004 | Ops UI | Orders page | Verify orders page renders | Open orders page | Table and form load |  |  |  |  |  |
| OPS-005 | Ops UI | Orders submit form | Verify UI order submission works | Submit valid order | Success response shown and list updates |  |  |  |  |  |
| OPS-006 | Ops UI | Order detail page | Verify order detail page loads | Open order detail route | Detail JSON/history visible |  |  |  |  |  |
| POS-001 | Positions | Positions API | Verify positions list works | GET positions endpoint | Updated positions visible |  |  |  |  |  |
| POS-002 | Ops UI | Positions page | Verify positions page renders | Open positions page | Positions table loads |  |  |  |  |  |
| RISK-001 | Risk | Pre-trade evaluation | Verify standard order passes risk | Submit normal-sized order | Risk decision is pass |  |  |  |  |  |
| RISK-002 | Risk | Kill switch API | Verify kill switch creation works | POST kill switch payload | Kill switch row created |  |  |  |  |  |
| RISK-003 | Risk | Kill switch enforcement | Verify kill switch blocks trading | Submit order while kill switch active | Order rejected |  |  |  |  |  |
| RISK-004 | Risk | Breaches API | Verify breaches list works | GET breaches endpoint | Breach rows visible after breach |  |  |  |  |  |
| RISK-005 | Risk | Drawdown tracker API | Verify drawdown tracker creation works | POST drawdown tracker payload | Tracker created |  |  |  |  |  |
| RISK-006 | Ops UI | Breaches page | Verify breaches page renders | Open breaches page | Rows load |  |  |  |  |  |
| RISK-007 | Ops UI | Kill switches page | Verify kill switches page renders | Open kill switches page | Rows load and create action works |  |  |  |  |  |
| EXEC-001 | Execution | Simulated execution | Verify execution simulate path works | Submit order through order service | Fill is recorded |  |  |  |  |  |
| EXEC-002 | Execution | Quality metrics API | Verify quality metrics endpoint works | GET execution quality metrics | Quality rows visible |  |  |  |  |  |
| EXEC-003 | Ops UI | Execution quality page | Verify quality page renders | Open execution quality page | Metrics table loads |  |  |  |  |  |
| REC-001 | Reconciliation | Create run | Verify reconciliation run creation works | POST run payload | Run ID returned |  |  |  |  |  |
| REC-002 | Reconciliation | List runs | Verify reconciliation runs list works | GET runs endpoint | Run row visible |  |  |  |  |  |
| REC-003 | Reconciliation | Create issue | Verify reconciliation issue creation works | POST issue payload | Issue ID returned |  |  |  |  |  |
| REC-004 | Reconciliation | List issues | Verify reconciliation issues list works | GET issues endpoint | Issue row visible |  |  |  |  |  |
| WF-001 | Workflow | Create workflow | Verify workflow creation works | POST workflow payload | Workflow ID returned |  |  |  |  |  |
| WF-002 | Workflow | Start run | Verify workflow run can start | POST workflow run payload | Workflow run ID returned |  |  |  |  |  |
| WF-003 | Admin UI | Workflows page | Verify workflows page actions work | Create demo workflow and run in UI | Successful responses shown |  |  |  |  |  |
| COMP-001 | Compliance | Create export | Verify compliance export creation works | POST export payload | Export ID returned |  |  |  |  |  |
| COMP-002 | Compliance | List exports | Verify compliance exports list works | GET exports endpoint | Export row visible |  |  |  |  |  |
| COMP-003 | Admin UI | Compliance exports page | Verify exports page action works | Click create export | Table updates with new row |  |  |  |  |  |
| E2E-001 | End-to-End | Core trading flow | Verify full happy path trading flow | Login → reference data → submit order → execution → position update | Full path succeeds |  |  |  |  |  |
| E2E-002 | End-to-End | Risk block flow | Verify blocked trading flow | Activate kill switch → submit order | Rejection occurs and evidence visible |  |  |  |  |  |
| E2E-003 | End-to-End | Governance flow | Verify workflow + compliance flow | Create workflow → start run → create export | All actions succeed |  |  |  |  |  |

---

# 5. Defect Log

Use this table for discovered defects.

| Defect ID | Module | Summary | Steps to Reproduce | Expected | Actual | Severity | Status | Owner | Notes |
|---|---|---|---|---|---|---|---|---|---|
| DEF-001 |  |  |  |  |  |  | Open |  |  |
| DEF-002 |  |  |  |  |  |  | Open |  |  |
| DEF-003 |  |  |  |  |  |  | Open |  |  |

---

# 6. Test Summary Sign-off

- Overall Result: PASS / FAIL / PARTIAL PASS
- Highest Severity Defect Found:
- Core Trading Path Status:
- UI Operability Status:
- Governance/Compliance Status:
- Recommended Next Fixes:
- Sign-off By:
- Sign-off Date:

---

# 7. Recommended Execution Order

Run the checklist in this order:

1. Infrastructure
2. Seed verification
3. Auth
4. Reference data APIs
5. Admin UI
6. Market data + features
7. Dataset + replay
8. Strategy runtime + signals + targets
9. Orders + positions + execution
10. Risk controls
11. Reconciliation
12. Workflows + compliance
13. Audit
14. End-to-end scenarios

This order gives the cleanest defect isolation.

