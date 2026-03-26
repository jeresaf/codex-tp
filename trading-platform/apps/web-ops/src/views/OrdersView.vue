<template>
  <div>
    <h1>Orders</h1>
    <form @submit.prevent="submit" style="display:grid;gap:10px;max-width:480px;margin-bottom:20px;">
      <input v-model="form.instrument_id" placeholder="Instrument ID" />
      <input v-model="form.venue_id" placeholder="Venue ID" />
      <select v-model="form.side"><option value="buy">buy</option><option value="sell">sell</option></select>
      <input v-model="form.quantity" placeholder="Quantity" />
      <input v-model="form.execution_price" placeholder="Execution Price" />
      <button type="submit">Submit Order</button>
    </form>
    <pre v-if="lastResponse">{{ lastResponse }}</pre>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Instrument</th><th>Side</th><th>Type</th><th>Quantity</th><th>Status</th><th>Open</th></tr></thead>
      <tbody>
        <tr v-for="row in rows" :key="row.id">
          <td>{{ row.id }}</td><td>{{ row.instrument_id }}</td><td>{{ row.side }}</td><td>{{ row.order_type }}</td><td>{{ row.quantity }}</td><td>{{ row.intent_status }}</td><td><router-link :to="`/orders/${row.id}`">Detail</router-link></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchOrders, submitOrder } from "../api/orders"
const rows = ref<any[]>([])
const lastResponse = ref("")
const form = ref({ instrument_id: "", venue_id: "", side: "buy", quantity: "1000", execution_price: "1.0850" })
async function load() { rows.value = await fetchOrders() }
async function submit() {
  const data = await submitOrder({ instrument_id: form.value.instrument_id, side: form.value.side, order_type: "market", quantity: form.value.quantity, tif: "IOC", venue_id: form.value.venue_id, execution_price: form.value.execution_price })
  lastResponse.value = JSON.stringify(data, null, 2)
  await load()
}
onMounted(load)
</script>
