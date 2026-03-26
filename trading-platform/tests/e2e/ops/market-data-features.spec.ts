import { test, expect } from "@playwright/test"
import { getSeededInstrumentId } from "../fixtures/ids"
import { ingestDemoCandle } from "../fixtures/api"

test("market data ingest endpoint accepts demo candle", async ({ request }) => {
  const instrumentId = await getSeededInstrumentId(request)
  const result = await ingestDemoCandle(request, instrumentId)
  expect(result.normalized_id).toBeTruthy()
})
