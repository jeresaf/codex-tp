import { http } from "./http"
export async function fetchPositions() {
  const { data } = await http.get("http://localhost:8008/api/positions")
  return data
}
