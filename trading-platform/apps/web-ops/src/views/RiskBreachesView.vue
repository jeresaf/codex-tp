<template>
  <div>
    <h1>Risk Breaches</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Breach Type</th><th>Severity</th><th>Status</th><th>Detected</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.breach_type }}</td><td>{{ row.severity }}</td><td>{{ row.status }}</td><td>{{ row.detected_at }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchBreaches } from "../api/risk"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchBreaches() })
</script>
