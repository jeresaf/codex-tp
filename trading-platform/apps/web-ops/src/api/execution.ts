import { http } from "./http"
export async function fetchExecutionQuality() {
  const { data } = await http.get("http://localhost:8007/api/execution/quality-metrics")
  return data
}
