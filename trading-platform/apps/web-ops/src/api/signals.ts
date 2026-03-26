import { http } from "./http"
export async function fetchSignals() {
  const { data } = await http.get("http://localhost:8012/api/signals")
  return data
}
