<template>
  <div>
    <h1>Portfolio Targets</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Instrument</th><th>Target Quantity</th><th>Delta Quantity</th><th>Correlation ID</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.instrument_id }}</td><td>{{ row.target_quantity }}</td><td>{{ row.delta_quantity }}</td><td>{{ row.correlation_id }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchTargets } from "../api/targets"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchTargets() })
</script>
