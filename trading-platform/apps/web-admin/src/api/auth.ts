import { http } from "./http"

export async function loginRequest(payload: { email: string; password: string }) {
  const { data } = await http.post("http://localhost:8001/api/auth/login", payload)
  return data
}
