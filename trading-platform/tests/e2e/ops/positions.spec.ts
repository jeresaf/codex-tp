import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops can view positions page", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/positions")
  await expect(page.getByText("Positions")).toBeVisible()
})
