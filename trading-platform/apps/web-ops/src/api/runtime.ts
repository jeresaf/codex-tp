import { http } from "./http"
export async function runSampleRuntime(payload: any) {
  const { data } = await http.post("http://localhost:8011/api/runtime/run-sample", payload)
  return data
}
