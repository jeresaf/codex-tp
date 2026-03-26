<template>
  <div>
    <h1>Ops Dashboard</h1>
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:16px;">
      <div style="padding:16px;border:1px solid #ddd;border-radius:8px;">Orders: {{ stats.orders }}</div>
      <div style="padding:16px;border:1px solid #ddd;border-radius:8px;">Positions: {{ stats.positions }}</div>
      <div style="padding:16px;border:1px solid #ddd;border-radius:8px;">Breaches: {{ stats.breaches }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive } from "vue"
import { fetchOrders } from "../api/orders"
import { fetchPositions } from "../api/positions"
import { fetchBreaches } from "../api/risk"
const stats = reactive({ orders: 0, positions: 0, breaches: 0 })
onMounted(async () => {
  stats.orders = (await fetchOrders()).length
  stats.positions = (await fetchPositions()).length
  stats.breaches = (await fetchBreaches()).length
})
</script>
