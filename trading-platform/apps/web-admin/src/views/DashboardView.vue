<template>
  <div>
    <PageHeader title="Dashboard" subtitle="Administrative overview" />
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:16px;">
      <div style="padding:16px;border:1px solid #ddd;border-radius:8px;">Markets: {{ stats.markets }}</div>
      <div style="padding:16px;border:1px solid #ddd;border-radius:8px;">Instruments: {{ stats.instruments }}</div>
      <div style="padding:16px;border:1px solid #ddd;border-radius:8px;">Strategies: {{ stats.strategies }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive } from "vue"
import PageHeader from "../components/PageHeader.vue"
import { fetchMarkets } from "../api/markets"
import { fetchInstruments } from "../api/instruments"
import { fetchStrategies } from "../api/strategies"
const stats = reactive({ markets: 0, instruments: 0, strategies: 0 })
onMounted(async () => {
  stats.markets = (await fetchMarkets()).length
  stats.instruments = (await fetchInstruments()).length
  stats.strategies = (await fetchStrategies()).length
})
</script>
