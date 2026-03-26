<template>
  <div>
    <h1>Execution Quality</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Broker Order</th><th>Slippage Bps</th><th>Fee Amount</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.broker_order_id }}</td><td>{{ row.slippage_bps }}</td><td>{{ row.total_fee_amount }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchExecutionQuality } from "../api/execution"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchExecutionQuality() })
</script>
