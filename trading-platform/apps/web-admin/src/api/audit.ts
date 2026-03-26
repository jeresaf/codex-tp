import { http } from "./http"
export async function fetchAudit() {
  const { data } = await http.get("http://localhost:8009/api/audit")
  return data
}
