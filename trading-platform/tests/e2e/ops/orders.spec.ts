import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"
import { getSeededInstrumentId, getSeededVenueId } from "../fixtures/ids"

test("ops can open orders page and submit order", async ({ page, request }) => {
  const instrumentId = await getSeededInstrumentId(request)
  const venueId = await getSeededVenueId(request)

  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/orders")

  await page.getByPlaceholder("Instrument ID").fill(instrumentId)
  await page.getByPlaceholder("Venue ID").fill(venueId)
  await page.getByPlaceholder("Quantity").fill("1000")
  await page.getByPlaceholder("Execution Price").fill("1.0850")
  await page.getByRole("button", { name: "Submit Order" }).click()

  await expect(page.locator("pre")).toBeVisible()
})
