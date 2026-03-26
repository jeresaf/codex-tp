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
