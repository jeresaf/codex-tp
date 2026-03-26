import { test, expect } from "@playwright/test"

test("ops login page loads", async ({ page }) => {
  await page.goto("/login")
  await expect(page.getByText("Ops Login")).toBeVisible()
})
