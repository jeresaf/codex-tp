import { http } from "./http"

export async function createWorkflow(payload: any) {
  const { data } = await http.post("http://localhost:8019/api/workflows", payload)
  return data
}

export async function startWorkflowRun(payload: any) {
  const { data } = await http.post("http://localhost:8019/api/workflows/runs", payload)
  return data
}
