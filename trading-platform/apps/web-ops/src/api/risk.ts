import { http } from "./http"
export async function fetchBreaches() {
  const { data } = await http.get("http://localhost:8006/api/risk/breaches")
  return data
}
export async function fetchKillSwitches() {
  const { data } = await http.get("http://localhost:8006/api/risk/kill-switches")
  return data
}
export async function createKillSwitch(payload: any) {
  const { data } = await http.post("http://localhost:8006/api/risk/kill-switches", payload)
  return data
}
export async function fetchDrawdownTrackers() {
  const { data } = await http.get("http://localhost:8006/api/risk/drawdown-trackers")
  return data
}
