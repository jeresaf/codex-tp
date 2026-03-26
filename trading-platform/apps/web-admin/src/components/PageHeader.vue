<template>
  <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:18px;gap:16px;">
    <div>
      <h1 style="margin:0 0 6px 0;">{{ title }}</h1>
      <p style="margin:0;color:#666;">{{ subtitle }}</p>
    </div>
    <div><slot name="actions" /></div>
  </div>
</template>

<script setup lang="ts">
defineProps<{ title: string; subtitle?: string }>()
</script>
