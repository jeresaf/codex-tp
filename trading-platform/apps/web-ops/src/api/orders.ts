import { http } from "./http"
export async function fetchOrders() {
  const { data } = await http.get("http://localhost:8005/api/orders")
  return data
}
export async function submitOrder(payload: any) {
  const { data } = await http.post("http://localhost:8005/api/orders/submit", payload)
  return data
}
export async function fetchOrderDetail(id: string) {
  const { data } = await http.get(`http://localhost:8005/api/orders/${id}`)
  return data
}
