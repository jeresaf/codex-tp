import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("admin login succeeds", async ({ page }) => {
  await loginUi(page, "http://localhost:3000", "admin@example.com", "admin", "Admin Login")
  await expect(page).toHaveURL(/dashboard/)
})

test("admin login fails with wrong password", async ({ page }) => {
  await page.goto("http://localhost:3000/login")
  await page.getByLabel("Email").fill("admin@example.com")
  await page.getByLabel("Password").fill("wrong")
  await page.getByRole("button", { name: "Login" }).click()
  await expect(page.getByText("Login failed")).toBeVisible()
})
