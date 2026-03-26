import { Page, APIRequestContext, expect } from "@playwright/test"

export async function loginUi(page: Page, baseUrl: string, email: string, password: string, heading: string) {
  await page.goto(`${baseUrl}/login`)
  await expect(page.getByText(heading)).toBeVisible()
  await page.getByLabel("Email").fill(email)
  await page.getByLabel("Password").fill(password)
  await page.getByRole("button", { name: "Login" }).click()
}

export async function loginApi(request: APIRequestContext, email: string, password: string) {
  const response = await request.post("http://localhost:8001/api/auth/login", {
    data: { email, password }
  })
  expect(response.ok()).toBeTruthy()
  return response.json()
}
