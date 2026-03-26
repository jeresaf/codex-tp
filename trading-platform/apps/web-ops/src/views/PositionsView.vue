<template>
  <div>
    <h1>Positions</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>Instrument</th><th>Net Quantity</th><th>Average Price</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.instrument_id }}</td><td>{{ row.net_quantity }}</td><td>{{ row.avg_price }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchPositions } from "../api/positions"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchPositions() })
</script>
