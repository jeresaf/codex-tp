<template>
  <span :style="badgeStyle"><slot /></span>
</template>

<script setup lang="ts">
const props = defineProps<{ tone?: "default" | "success" | "warning" | "danger" }>()
const map = {
  default: "background:#eee;color:#333;",
  success: "background:#daf5dd;color:#166534;",
  warning: "background:#fef3c7;color:#92400e;",
  danger: "background:#fee2e2;color:#991b1b;"
}
const badgeStyle = `display:inline-block;padding:4px 10px;border-radius:999px;font-size:12px;font-weight:600;${map[props.tone || "default"]}`
</script>
