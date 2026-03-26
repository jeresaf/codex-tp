# Playwright E2E Automation Pack for the Trading Platform

This pack gives you a practical first automation layer that mirrors the manual QA walkthrough.

It includes:
- Playwright workspace strategy
- shared helpers
- admin and ops test configs
- seeded login helper
- API-assisted setup helpers
- core end-to-end specs
- CI job outline for GitHub Actions

---

# 1. Recommended automation structure

Use a root-level Playwright workspace so both UIs are tested together.

```text
tests/
├─ e2e/
│  ├─ fixtures/
│  │  ├─ auth.ts
│  │  ├─ ids.ts
│  │  └─ api.ts
│  ├─ admin/
│  │  ├─ auth.spec.ts
│  │  ├─ reference-data.spec.ts
│  │  ├─ workflows.spec.ts
│  │  └─ compliance.spec.ts
│  ├─ ops/
│  │  ├─ auth.spec.ts
│  │  ├─ orders.spec.ts
│  │  ├─ positions.spec.ts
│  │  ├─ risk.spec.ts
│  │  ├─ execution-quality.spec.ts
│  │  ├─ signals-targets.spec.ts
│  │  └─ market-data-features.spec.ts
│  └─ smoke/
│     └─ platform-smoke.spec.ts
├─ playwright.config.ts
└─ package.json
```

This is better than keeping separate Playwright projects inside each app because:
- shared login helpers are cleaner
- shared seeded IDs are reusable
- cross-app workflows are easier to automate
- CI is simpler

---

# 2. Root Playwright package

## `tests/package.json`

```json
{
  "name": "trading-platform-e2e",
  "private": true,
  "version": "0.1.0",
  "scripts": {
    "test": "playwright test",
    "test:headed": "playwright test --headed",
    "test:smoke": "playwright test tests/e2e/smoke",
    "report": "playwright show-report"
  },
  "devDependencies": {
    "@playwright/test": "^1.54.1",
    "typescript": "^5.7.3"
  }
}
```

---

# 3. Root Playwright config

## `tests/playwright.config.ts`

```ts
import { defineConfig } from "@playwright/test"

export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure"
  },
  projects: [
    {
      name: "chromium",
      use: {
        browserName: "chromium"
      }
    }
  ]
})
```

---

# 4. Shared fixture helpers

## `tests/e2e/fixtures/auth.ts`

```ts
import { Page, APIRequestContext, expect } from "@playwright/test"

export async function loginUi(page: Page, baseUrl: string, email: string, password: string, heading: string) {
  await page.goto(`${baseUrl}/login`)
  await expect(page.getByText(heading)).toBeVisible()
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password").fill(password)
  await page.getByRole("button", { name: "Login" }).click()
}

export async function loginApi(request: APIRequestContext, email: string, password: string) {
  const response = await request.post("http://localhost:8001/api/auth/login", {
    data: { email, password }
  })
  expect(response.ok()).toBeTruthy()
  return response.json()
}
```

## `tests/e2e/fixtures/ids.ts`

```ts
import { APIRequestContext, expect } from "@playwright/test"

export async function getSeededInstrumentId(request: APIRequestContext, symbol = "EURUSD") {
  const login = await request.post("http://localhost:8001/api/auth/login", {
    data: { email: "admin@example.com", password: "admin" }
  })
  expect(login.ok()).toBeTruthy()
  const auth = await login.json()

  const response = await request.get("http://localhost:8003/api/instruments", {
    headers: { Authorization: `Bearer ${auth.access_token}` }
  })
  expect(response.ok()).toBeTruthy()
  const rows = await response.json()
  const found = rows.find((x: any) => x.canonical_symbol === symbol)
  expect(found).toBeTruthy()
  return found.id
}

export async function getSeededVenueIdFromDbSafe(request: APIRequestContext) {
  const response = await request.get("http://localhost:8010/api/simulator/status")
  expect(response.ok()).toBeTruthy()
  return "REPLACE_WITH_DB_OR_ENDPOINT_LOOKUP"
}
```

## `tests/e2e/fixtures/api.ts`

```ts
import { APIRequestContext, expect } from "@playwright/test"

export async function createKillSwitch(request: APIRequestContext, token: string) {
  const response = await request.post("http://localhost:8006/api/risk/kill-switches", {
    headers: { Authorization: `Bearer ${token}` },
    data: {
      scope_type: "global",
      switch_action: "reject_new_orders",
      reason: "Playwright test"
    }
  })
  expect(response.ok()).toBeTruthy()
  return response.json()
}

export async function ingestDemoCandle(request: APIRequestContext, instrumentId: string) {
  const now = new Date()
  const open = new Date(now.getTime() - 60_000)
  const response = await request.post("http://localhost:8014/api/market-data/ingest-candle", {
    data: {
      instrument_id: instrumentId,
      open_time: open.toISOString(),
      close_time: now.toISOString(),
      open: 1.08,
      high: 1.086,
      low: 1.079,
      close: 1.085,
      volume: 1000,
      source: "playwright-feed"
    }
  })
  expect(response.ok()).toBeTruthy()
  return response.json()
}
```

---

# 5. Admin app tests

## `tests/e2e/admin/auth.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("admin login succeeds", async ({ page }) => {
  await loginUi(page, "http://localhost:3000", "admin@example.com", "admin", "Admin Login")
  await expect(page).toHaveURL(/dashboard/)
})

test("admin login fails with wrong password", async ({ page }) => {
  await page.goto("http://localhost:3000/login")
  await page.getByLabel("Email").fill("admin@example.com")
  await page.getByLabel("Password").fill("wrong")
  await page.getByRole("button", { name: "Login" }).click()
  await expect(page.getByText("Login failed")).toBeVisible()
})
```

## `tests/e2e/admin/reference-data.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("admin can view markets instruments and strategies", async ({ page }) => {
  await loginUi(page, "http://localhost:3000", "admin@example.com", "admin", "Admin Login")

  await page.goto("http://localhost:3000/markets")
  await expect(page.getByText("Markets")).toBeVisible()
  await expect(page.getByText("forex")).toBeVisible()

  await page.goto("http://localhost:3000/instruments")
  await expect(page.getByText("Instruments")).toBeVisible()
  await expect(page.getByText("EURUSD")).toBeVisible()

  await page.goto("http://localhost:3000/strategies")
  await expect(page.getByText("Strategies")).toBeVisible()
  await expect(page.getByText("fx_ma_cross")).toBeVisible()
})
```

## `tests/e2e/admin/workflows.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("admin can create demo workflow and start run", async ({ page }) => {
  await loginUi(page, "http://localhost:3000", "admin@example.com", "admin", "Admin Login")
  await page.goto("http://localhost:3000/workflows")
  await page.getByRole("button", { name: "Create Demo Workflow" }).click()
  await expect(page.locator("pre")).toBeVisible()
  await page.getByRole("button", { name: "Start Demo Run" }).click()
  await expect(page.locator("pre")).toContainText("id")
})
```

## `tests/e2e/admin/compliance.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("admin can create compliance export", async ({ page }) => {
  await loginUi(page, "http://localhost:3000", "admin@example.com", "admin", "Admin Login")
  await page.goto("http://localhost:3000/compliance/exports")
  await page.getByRole("button", { name: "Create Export" }).click()
  await expect(page.getByText("audit_snapshot")).toBeVisible()
})
```

---

# 6. Ops app tests

## `tests/e2e/ops/auth.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops login succeeds", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await expect(page).toHaveURL(/dashboard/)
})
```

## `tests/e2e/ops/orders.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi, loginApi } from "../fixtures/auth"
import { getSeededInstrumentId } from "../fixtures/ids"

test("ops can open orders page and submit order", async ({ page, request }) => {
  const auth = await loginApi(request, "admin@example.com", "admin")
  const instrumentId = await getSeededInstrumentId(request)

  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/orders")

  await page.getByPlaceholder("Instrument ID").fill(instrumentId)
  await page.getByPlaceholder("Venue ID").fill("REPLACE_WITH_SEEDED_VENUE_ID")
  await page.getByPlaceholder("Quantity").fill("1000")
  await page.getByPlaceholder("Execution Price").fill("1.0850")
  await page.getByRole("button", { name: "Submit Order" }).click()

  await expect(page.locator("pre")).toBeVisible()
})
```

## `tests/e2e/ops/positions.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops can view positions page", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/positions")
  await expect(page.getByText("Positions")).toBeVisible()
})
```

## `tests/e2e/ops/risk.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops can create and view kill switches", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/risk/kill-switches")
  await page.getByRole("button", { name: "Create Global Kill Switch" }).click()
  await expect(page.getByText("global")).toBeVisible()
})

test("ops can view breaches page", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/risk/breaches")
  await expect(page.getByText("Risk Breaches")).toBeVisible()
})
```

## `tests/e2e/ops/execution-quality.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops can view execution quality page", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/executions/quality")
  await expect(page.getByText("Execution Quality")).toBeVisible()
})
```

## `tests/e2e/ops/signals-targets.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops can view signals and targets pages", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")

  await page.goto("http://localhost:3001/signals")
  await expect(page.getByText("Signals")).toBeVisible()

  await page.goto("http://localhost:3001/targets")
  await expect(page.getByText("Portfolio Targets")).toBeVisible()
})
```

## `tests/e2e/ops/market-data-features.spec.ts`

```ts
import { test, expect } from "@playwright/test"
import { getSeededInstrumentId } from "../fixtures/ids"
import { ingestDemoCandle } from "../fixtures/api"

test("market data ingest endpoint accepts demo candle", async ({ request }) => {
  const instrumentId = await getSeededInstrumentId(request)
  const result = await ingestDemoCandle(request, instrumentId)
  expect(result.normalized_id).toBeTruthy()
})
```

---

# 7. Smoke suite

## `tests/e2e/smoke/platform-smoke.spec.ts`

```ts
import { test, expect } from "@playwright/test"

const healthUrls = [
  "http://localhost:8001/health/live",
  "http://localhost:8002/health/live",
  "http://localhost:8003/health/live",
  "http://localhost:8004/health/live",
  "http://localhost:8005/health/live",
  "http://localhost:8006/health/live",
  "http://localhost:8007/health/live",
  "http://localhost:8008/health/live",
  "http://localhost:8009/health/live"
]

test("core services are healthy", async ({ request }) => {
  for (const url of healthUrls) {
    const response = await request.get(url)
    expect(response.ok()).toBeTruthy()
  }
})
```

---

# 8. GitHub Actions CI workflow

## `.github/workflows/e2e.yml`

```yaml
name: e2e

on:
  push:
    branches: [main]
  pull_request:

jobs:
  playwright:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Start stack
        run: |
          docker compose up --build -d
          bash scripts/migrate/run_all.sh
          bash scripts/seed/run_all.sh

      - name: Install Playwright deps
        working-directory: tests
        run: |
          npm install
          npx playwright install --with-deps

      - name: Run smoke
        working-directory: tests
        run: npm run test:smoke

      - name: Run full e2e
        working-directory: tests
        run: npm test

      - name: Upload report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: tests/playwright-report
```

---

# 9. Important implementation note

One test placeholder still needs to be replaced before the order submission UI test becomes fully automatic:
- `REPLACE_WITH_SEEDED_VENUE_ID`

You have two good options:

## Option A
Add a venues list endpoint and fetch the seeded `oanda-demo` venue ID cleanly.

## Option B
Query the DB in a helper script and export it into Playwright environment variables before tests run.

Best option: **add a venues API**.

---

# 10. Recommended first automation execution order

Run these first:
1. smoke suite
2. admin auth
3. admin reference data
4. ops auth
5. ops positions page
6. ops risk pages
7. admin workflows/compliance
8. order flow after venue lookup is automated

This reduces false negatives while the stack matures.

---

# 11. What this automation pack gives you immediately

You now have the foundation for:
- regression testing
- CI validation
- repeatable operator UI verification
- faster defect isolation after changes
- a path toward production-grade release gates

---

# 12. Strongest next automation artifact

The next strongest artifact is a **repo bootstrap writer for the full Playwright workspace**, which will write:
- `tests/package.json`
- `tests/playwright.config.ts`
- all fixture files
- all e2e specs
- GitHub Actions workflow

That will let you drop the automation suite into the repo in one pass.

