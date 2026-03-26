<template>
  <div>
    <h1>Signals</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Deployment</th><th>Instrument</th><th>Direction</th><th>Strength</th><th>Confidence</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.strategy_deployment_id }}</td><td>{{ row.instrument_id }}</td><td>{{ row.direction }}</td><td>{{ row.strength }}</td><td>{{ row.confidence }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchSignals } from "../api/signals"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchSignals() })
</script>
