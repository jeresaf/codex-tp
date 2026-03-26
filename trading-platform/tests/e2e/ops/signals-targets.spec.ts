import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops can view signals and targets pages", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")

  await page.goto("http://localhost:3001/signals")
  await expect(page.getByText("Signals")).toBeVisible()

  await page.goto("http://localhost:3001/targets")
  await expect(page.getByText("Portfolio Targets")).toBeVisible()
})
