import { test, expect } from "@playwright/test"

test("admin login page loads", async ({ page }) => {
  await page.goto("/login")
  await expect(page.getByText("Admin Login")).toBeVisible()
})
