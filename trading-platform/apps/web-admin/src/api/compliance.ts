import { http } from "./http"

export async function createComplianceExport(payload: any) {
  const { data } = await http.post("http://localhost:8020/api/compliance/exports", payload)
  return data
}

export async function fetchComplianceExports() {
  const { data } = await http.get("http://localhost:8020/api/compliance/exports")
  return data
}
