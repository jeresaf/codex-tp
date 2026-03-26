<template>
  <div>
    <PageHeader title="Compliance Exports" subtitle="Export governance evidence">
      <template #actions><button @click="createDemoExport">Create Export</button></template>
    </PageHeader>
    <DataTable :columns="columns" :rows="rows" id-field="id" />
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import PageHeader from "../components/PageHeader.vue"
import DataTable from "../components/DataTable.vue"
import { createComplianceExport, fetchComplianceExports } from "../api/compliance"
const rows = ref<any[]>([])
const columns = [
  { key: "id", label: "ID" },
  { key: "export_type", label: "Export Type" },
  { key: "status", label: "Status" }
]
async function load() { rows.value = await fetchComplianceExports() }
async function createDemoExport() {
  await createComplianceExport({ export_type: "audit_snapshot", scope_type: "global", scope_id: null, format: "json", request_json: {} })
  await load()
}
onMounted(load)
</script>
