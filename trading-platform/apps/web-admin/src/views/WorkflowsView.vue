<template>
  <div>
    <PageHeader title="Workflows" subtitle="Create and start workflow definitions">
      <template #actions><button @click="createDemoWorkflow">Create Demo Workflow</button></template>
    </PageHeader>
    <button @click="startDemoRun" style="margin-bottom:16px;">Start Demo Run</button>
    <pre v-if="lastResponse">{{ lastResponse }}</pre>
  </div>
</template>
<script setup lang="ts">
import { ref } from "vue"
import PageHeader from "../components/PageHeader.vue"
import { createWorkflow, startWorkflowRun } from "../api/workflows"
const workflowId = ref("")
const lastResponse = ref("")
async function createDemoWorkflow() {
  const data = await createWorkflow({ workflow_code: "demo_approval", name: "Demo Approval", description: "Demo workflow", scope_type: "strategy", definition_json: { states: ["start", "approved"] }, enabled: true })
  workflowId.value = data.id
  lastResponse.value = JSON.stringify(data, null, 2)
}
async function startDemoRun() {
  if (!workflowId.value) return
  const data = await startWorkflowRun({ workflow_id: workflowId.value, subject_type: "strategy", subject_id: crypto.randomUUID(), context_json: {} })
  lastResponse.value = JSON.stringify(data, null, 2)
}
</script>
