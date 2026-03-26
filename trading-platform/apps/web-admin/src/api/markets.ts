import { http } from "./http"
export async function fetchMarkets() {
  const { data } = await http.get("http://localhost:8002/api/markets")
  return data
}
