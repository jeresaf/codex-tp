<template><div><h1>Order Detail</h1><pre v-if="detail">{{ JSON.stringify(detail, null, 2) }}</pre></div></template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { useRoute } from "vue-router"
import { fetchOrderDetail } from "../api/orders"
const route = useRoute()
const detail = ref<any>(null)
onMounted(async () => { detail.value = await fetchOrderDetail(String(route.params.id)) })
</script>
