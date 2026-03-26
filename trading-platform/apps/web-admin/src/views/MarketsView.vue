<template><div><PageHeader title="Markets" subtitle="Registered market types" /><DataTable :columns="columns" :rows="rows" id-field="id" /></div></template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import PageHeader from "../components/PageHeader.vue"
import DataTable from "../components/DataTable.vue"
import { fetchMarkets } from "../api/markets"
const rows = ref<any[]>([])
const columns = [
  { key: "code", label: "Code" },
  { key: "name", label: "Name" },
  { key: "asset_class", label: "Asset Class" },
  { key: "timezone", label: "Timezone" },
  { key: "status", label: "Status" }
]
onMounted(async () => { rows.value = await fetchMarkets() })
</script>
