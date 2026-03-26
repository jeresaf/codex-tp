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
