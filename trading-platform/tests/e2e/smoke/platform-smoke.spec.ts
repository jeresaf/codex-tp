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
