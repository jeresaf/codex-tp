<template>
  <div>
    <h1>Kill Switches</h1>
    <button @click="createDemo">Create Global Kill Switch</button>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;margin-top:16px;">
      <thead><tr><th>ID</th><th>Scope Type</th><th>Scope ID</th><th>Action</th><th>Status</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.scope_type }}</td><td>{{ row.scope_id }}</td><td>{{ row.switch_action }}</td><td>{{ row.status }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { createKillSwitch, fetchKillSwitches } from "../api/risk"
const rows = ref<any[]>([])
async function load() { rows.value = await fetchKillSwitches() }
async function createDemo() {
  await createKillSwitch({ scope_type: "global", switch_action: "reject_new_orders", reason: "UI test" })
  await load()
}
onMounted(load)
</script>
