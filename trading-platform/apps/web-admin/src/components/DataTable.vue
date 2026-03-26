<template>
  <div style="overflow:auto;border:1px solid #ddd;border-radius:8px;">
    <table style="width:100%;border-collapse:collapse;">
      <thead>
        <tr>
          <th v-for="col in columns" :key="col.key" style="text-align:left;padding:10px;border-bottom:1px solid #ddd;">{{ col.label }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row[idField || 'id']">
          <td v-for="col in columns" :key="col.key" style="padding:10px;border-bottom:1px solid #f0f0f0;vertical-align:top;">
            <slot :name="col.key" :row="row">{{ row[col.key] }}</slot>
          </td>
        </tr>
        <tr v-if="!rows.length"><td :colspan="columns.length" style="padding:16px;color:#666;">No records found.</td></tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
defineProps<{ columns: { key: string; label: string }[]; rows: Record<string, any>[]; idField?: string }>()
</script>
