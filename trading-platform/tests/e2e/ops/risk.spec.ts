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
