import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"

test("ops login succeeds", async ({ page }) => {
  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await expect(page).toHaveURL(/dashboard/)
})
