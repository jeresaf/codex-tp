<template><div><PageHeader title="Audit" subtitle="Recent platform audit events" /><DataTable :columns="columns" :rows="rows" id-field="id" /></div></template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import PageHeader from "../components/PageHeader.vue"
import DataTable from "../components/DataTable.vue"
import { fetchAudit } from "../api/audit"
const rows = ref<any[]>([])
const columns = [
  { key: "created_at", label: "Time" },
  { key: "event_type", label: "Event" },
  { key: "resource_type", label: "Resource Type" },
  { key: "resource_id", label: "Resource ID" }
]
onMounted(async () => { rows.value = await fetchAudit() })
</script>
