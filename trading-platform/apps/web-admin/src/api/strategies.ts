import { http } from "./http"
export async function fetchStrategies() {
  const { data } = await http.get("http://localhost:8004/api/strategies")
  return data
}
