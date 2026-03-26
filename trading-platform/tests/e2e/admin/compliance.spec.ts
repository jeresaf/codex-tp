import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("admin can create compliance export", async ({ page }) => {
  await loginUi(page, "http://localhost:3000", "admin@example.com", "admin", "Admin Login")
  await page.goto("http://localhost:3000/compliance/exports")
  await page.getByRole("button", { name: "Create Export" }).click()
  await expect(page.getByText("audit_snapshot")).toBeVisible()
})
