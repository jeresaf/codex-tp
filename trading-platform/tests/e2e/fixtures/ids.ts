import { APIRequestContext, expect } from "@playwright/test"

export async function getAdminToken(request: APIRequestContext) {
  const login = await request.post("http://localhost:8001/api/auth/login", {
    data: { email: "admin@example.com", password: "admin" }
  })
  expect(login.ok()).toBeTruthy()
  const auth = await login.json()
  return auth.access_token as string
}

export async function getSeededInstrumentId(request: APIRequestContext, symbol = "EURUSD") {
  const token = await getAdminToken(request)
  const response = await request.get("http://localhost:8003/api/instruments", {
    headers: { Authorization: `Bearer ${token}` }
  })
  expect(response.ok()).toBeTruthy()
  const rows = await response.json()
  const found = rows.find((x: any) => x.canonical_symbol === symbol)
  expect(found).toBeTruthy()
  return found.id as string
}

export async function getSeededVenueId(request: APIRequestContext, code = "oanda-demo") {
  const token = await getAdminToken(request)
  const response = await request.get(`http://localhost:8002/api/venues?code=${encodeURIComponent(code)}`, {
    headers: { Authorization: `Bearer ${token}` }
  })
  expect(response.ok()).toBeTruthy()
  const rows = await response.json()
  const found = rows.find((x: any) => x.code === code)
  expect(found).toBeTruthy()
  return found.id as string
}
