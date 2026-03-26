<template><div><PageHeader title="Instruments" subtitle="Canonical tradable instruments" /><DataTable :columns="columns" :rows="rows" id-field="id" /></div></template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import PageHeader from "../components/PageHeader.vue"
import DataTable from "../components/DataTable.vue"
import { fetchInstruments } from "../api/instruments"
const rows = ref<any[]>([])
const columns = [
  { key: "canonical_symbol", label: "Symbol" },
  { key: "asset_class", label: "Asset Class" },
  { key: "base_asset", label: "Base" },
  { key: "quote_asset", label: "Quote" },
  { key: "status", label: "Status" }
]
onMounted(async () => { rows.value = await fetchInstruments() })
</script>
