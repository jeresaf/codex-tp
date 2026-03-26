#!/usr/bin/env bash
set -euo pipefail

# Repo bootstrap writer for the full Playwright workspace.
# Run inside the existing trading-platform repo root.

ROOT="$(pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ]; then
  echo "Run this inside the trading-platform repo root."
  exit 1
fi

mkdir -p \
  tests/e2e/fixtures \
  tests/e2e/admin \
  tests/e2e/ops \
  tests/e2e/smoke \
  .github/workflows

cat > tests/package.json <<'EOF'
{
  "name": "trading-platform-e2e",
  "private": true,
  "version": "0.1.0",
  "scripts": {
    "test": "playwright test",
    "test:headed": "playwright test --headed",
    "test:smoke": "playwright test e2e/smoke",
    "report": "playwright show-report"
  },
  "devDependencies": {
    "@playwright/test": "^1.54.1",
    "typescript": "^5.7.3"
  }
}
EOF

cat > tests/playwright.config.ts <<'EOF'
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
EOF

cat > tests/e2e/fixtures/auth.ts <<'EOF'
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
EOF

cat > tests/e2e/fixtures/ids.ts <<'EOF'
import { APIRequestContext, expect } from "@playwright/test"

export async function getAdminToken(request: APIRequestContext) {
  const login = await request.post("http://localhost:8001/api/auth/login", {
    data: { email: "admin@example.com", password: "admin" }
  })
  expect(login.ok()).toBeTruthy()
  const auth = await login.json()
  return auth.access_token as string
}

export async function getSeededInstrumentId(request: APIRequestContext, symbol = "EURUSD") {
  const token = await getAdminToken(request)
  const response = await request.get("http://localhost:8003/api/instruments", {
    headers: { Authorization: `Bearer ${token}` }
  })
  expect(response.ok()).toBeTruthy()
  const rows = await response.json()
  const found = rows.find((x: any) => x.canonical_symbol === symbol)
  expect(found).toBeTruthy()
  return found.id as string
}

export async function getSeededVenueId(request: APIRequestContext, code = "oanda-demo") {
  const token = await getAdminToken(request)
  const response = await request.get("http://localhost:8002/api/markets", {
    headers: { Authorization: `Bearer ${token}` }
  })
  expect(response.ok()).toBeTruthy()
  // Placeholder until a venues endpoint is added.
  // Replace with a real lookup once /api/venues exists.
  const fromEnv = process.env.PLAYWRIGHT_VENUE_ID
  expect(fromEnv, "PLAYWRIGHT_VENUE_ID must be set until venues API exists").toBeTruthy()
  return fromEnv as string
}
EOF

cat > tests/e2e/fixtures/api.ts <<'EOF'
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
EOF

cat > tests/e2e/admin/auth.spec.ts <<'EOF'
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
EOF

cat > tests/e2e/admin/reference-data.spec.ts <<'EOF'
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
EOF

cat > tests/e2e/admin/workflows.spec.ts <<'EOF'
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
EOF

cat > tests/e2e/admin/compliance.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("admin can create compliance export", async ({ page }) => {
  await loginUi(page, "http://localhost:3000", "admin@example.com", "admin", "Admin Login")
  await page.goto("http://localhost:3000/compliance/exports")
  await page.getByRole("button", { name: "Create Export" }).click()
  await expect(page.getByText("audit_snapshot")).toBeVisible()
})
EOF

cat > tests/e2e/ops/auth.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops login succeeds", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await expect(page).toHaveURL(/dashboard/)
})
EOF

cat > tests/e2e/ops/orders.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"
import { getSeededInstrumentId, getSeededVenueId } from "../fixtures/ids"

test("ops can open orders page and submit order", async ({ page, request }) => {
  const instrumentId = await getSeededInstrumentId(request)
  const venueId = await getSeededVenueId(request)

  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/orders")

  await page.getByPlaceholder("Instrument ID").fill(instrumentId)
  await page.getByPlaceholder("Venue ID").fill(venueId)
  await page.getByPlaceholder("Quantity").fill("1000")
  await page.getByPlaceholder("Execution Price").fill("1.0850")
  await page.getByRole("button", { name: "Submit Order" }).click()

  await expect(page.locator("pre")).toBeVisible()
})
EOF

cat > tests/e2e/ops/positions.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops can view positions page", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/positions")
  await expect(page.getByText("Positions")).toBeVisible()
})
EOF

cat > tests/e2e/ops/risk.spec.ts <<'EOF'
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
EOF

cat > tests/e2e/ops/execution-quality.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops can view execution quality page", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/executions/quality")
  await expect(page.getByText("Execution Quality")).toBeVisible()
})
EOF

cat > tests/e2e/ops/signals-targets.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops can view signals and targets pages", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")

  await page.goto("http://localhost:3001/signals")
  await expect(page.getByText("Signals")).toBeVisible()

  await page.goto("http://localhost:3001/targets")
  await expect(page.getByText("Portfolio Targets")).toBeVisible()
})
EOF

cat > tests/e2e/ops/market-data-features.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"
import { getSeededInstrumentId } from "../fixtures/ids"
import { ingestDemoCandle } from "../fixtures/api"

test("market data ingest endpoint accepts demo candle", async ({ request }) => {
  const instrumentId = await getSeededInstrumentId(request)
  const result = await ingestDemoCandle(request, instrumentId)
  expect(result.normalized_id).toBeTruthy()
})
EOF

cat > tests/e2e/smoke/platform-smoke.spec.ts <<'EOF'
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
EOF

cat > .github/workflows/e2e.yml <<'EOF'
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
          docker-compose up --build -d
          bash scripts/migrate/run_all.sh
          bash scripts/seed/run_all.sh

      - name: Set seeded venue id
        run: echo "PLAYWRIGHT_VENUE_ID=${{ secrets.PLAYWRIGHT_VENUE_ID }}" >> $GITHUB_ENV

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
EOF

echo "Playwright workspace bootstrap applied."
echo "Next: cd tests && npm install && npx playwright install --with-deps && npm run test:smoke"
