import { http } from "./http"
export async function fetchInstruments() {
  const { data } = await http.get("http://localhost:8003/api/instruments")
  return data
}
