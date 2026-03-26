import axios from "axios"

export const http = axios.create()

http.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token")
  if (token) {
    config.headers = config.headers || {}
    config.headers.Authorization = `Bearer ${token}`
  }
  config.headers = config.headers || {}
  config.headers["X-Correlation-ID"] = crypto.randomUUID()
  return config
})
