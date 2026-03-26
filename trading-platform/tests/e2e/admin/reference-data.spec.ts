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
