import { http } from "./http"
export async function fetchTargets() {
  const { data } = await http.get("http://localhost:8013/api/targets")
  return data
}
