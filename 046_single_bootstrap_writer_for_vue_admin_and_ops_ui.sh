#!/usr/bin/env bash
set -euo pipefail

# Single bootstrap writer for Vue admin + ops UI.
# Run inside the existing trading-platform repo root.

ROOT="$(pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ]; then
  echo "Run this inside the trading-platform repo root."
  exit 1
fi

mkdir -p \
  apps/web-admin/src/{api,components,layouts,router,stores,views} \
  apps/web-admin/tests/e2e \
  apps/web-ops/src/{api,components,layouts,router,stores,views} \
  apps/web-ops/tests/e2e

cat > apps/web-admin/package.json <<'EOF'
{
  "name": "web-admin",
  "private": true,
  "version": "0.1.0",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 3000",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0 --port 3000",
    "test:e2e": "playwright test"
  },
  "dependencies": {
    "axios": "^1.8.0",
    "pinia": "^3.0.1",
    "vue": "^3.5.13",
    "vue-router": "^4.5.0"
  },
  "devDependencies": {
    "@playwright/test": "^1.54.1",
    "@vitejs/plugin-vue": "^5.2.1",
    "typescript": "^5.7.3",
    "vite": "^6.1.0"
  }
}
EOF

cat > apps/web-admin/vite.config.ts <<'EOF'
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"

export default defineConfig({
  plugins: [vue()]
})
EOF

cat > apps/web-admin/src/main.ts <<'EOF'
import { createApp } from "vue"
import { createPinia } from "pinia"
import App from "./App.vue"
import router from "./router"

createApp(App).use(createPinia()).use(router).mount("#app")
EOF

cat > apps/web-admin/src/App.vue <<'EOF'
<template>
  <router-view />
</template>
EOF

cat > apps/web-admin/src/api/http.ts <<'EOF'
import axios from "axios"

export const http = axios.create()

http.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token")
  if (token) {
    config.headers = config.headers || {}
    config.headers.Authorization = `Bearer ${token}`
  }
  config.headers = config.headers || {}
  config.headers["X-Correlation-ID"] = crypto.randomUUID()
  return config
})
EOF

cat > apps/web-admin/src/api/auth.ts <<'EOF'
import { http } from "./http"

export async function loginRequest(payload: { email: string; password: string }) {
  const { data } = await http.post("http://localhost:8001/api/auth/login", payload)
  return data
}
EOF

cat > apps/web-admin/src/api/markets.ts <<'EOF'
import { http } from "./http"
export async function fetchMarkets() {
  const { data } = await http.get("http://localhost:8002/api/markets")
  return data
}
EOF

cat > apps/web-admin/src/api/instruments.ts <<'EOF'
import { http } from "./http"
export async function fetchInstruments() {
  const { data } = await http.get("http://localhost:8003/api/instruments")
  return data
}
EOF

cat > apps/web-admin/src/api/strategies.ts <<'EOF'
import { http } from "./http"
export async function fetchStrategies() {
  const { data } = await http.get("http://localhost:8004/api/strategies")
  return data
}
EOF

cat > apps/web-admin/src/api/audit.ts <<'EOF'
import { http } from "./http"
export async function fetchAudit() {
  const { data } = await http.get("http://localhost:8009/api/audit")
  return data
}
EOF

cat > apps/web-admin/src/api/workflows.ts <<'EOF'
import { http } from "./http"

export async function createWorkflow(payload: any) {
  const { data } = await http.post("http://localhost:8019/api/workflows", payload)
  return data
}

export async function startWorkflowRun(payload: any) {
  const { data } = await http.post("http://localhost:8019/api/workflows/runs", payload)
  return data
}
EOF

cat > apps/web-admin/src/api/compliance.ts <<'EOF'
import { http } from "./http"

export async function createComplianceExport(payload: any) {
  const { data } = await http.post("http://localhost:8020/api/compliance/exports", payload)
  return data
}

export async function fetchComplianceExports() {
  const { data } = await http.get("http://localhost:8020/api/compliance/exports")
  return data
}
EOF

cat > apps/web-admin/src/stores/auth.ts <<'EOF'
import { defineStore } from "pinia"
import { loginRequest } from "../api/auth"

export const useAuthStore = defineStore("auth", {
  state: () => ({
    token: localStorage.getItem("access_token") || "",
    user: JSON.parse(localStorage.getItem("auth_user") || "null") as null | Record<string, any>,
    roles: JSON.parse(localStorage.getItem("auth_roles") || "[]") as string[],
    permissions: JSON.parse(localStorage.getItem("auth_permissions") || "[]") as string[]
  }),
  getters: {
    isAuthenticated: (state) => !!state.token,
    hasRole: (state) => (role: string) => state.roles.includes(role)
  },
  actions: {
    async login(email: string, password: string) {
      const data = await loginRequest({ email, password })
      this.token = data.access_token
      this.user = data.user
      this.roles = data.roles || []
      this.permissions = data.permissions || []
      localStorage.setItem("access_token", this.token)
      localStorage.setItem("auth_user", JSON.stringify(this.user))
      localStorage.setItem("auth_roles", JSON.stringify(this.roles))
      localStorage.setItem("auth_permissions", JSON.stringify(this.permissions))
    },
    logout() {
      this.token = ""
      this.user = null
      this.roles = []
      this.permissions = []
      localStorage.removeItem("access_token")
      localStorage.removeItem("auth_user")
      localStorage.removeItem("auth_roles")
      localStorage.removeItem("auth_permissions")
    }
  }
})
EOF

cat > apps/web-admin/src/router/index.ts <<'EOF'
import { createRouter, createWebHistory } from "vue-router"
import LoginView from "../views/LoginView.vue"
import ForbiddenView from "../views/ForbiddenView.vue"
import AdminLayout from "../layouts/AdminLayout.vue"
import DashboardView from "../views/DashboardView.vue"
import MarketsView from "../views/MarketsView.vue"
import InstrumentsView from "../views/InstrumentsView.vue"
import StrategiesView from "../views/StrategiesView.vue"
import AuditView from "../views/AuditView.vue"
import WorkflowsView from "../views/WorkflowsView.vue"
import ComplianceExportsView from "../views/ComplianceExportsView.vue"
import { useAuthStore } from "../stores/auth"

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/login", component: LoginView, meta: { guestOnly: true } },
    { path: "/forbidden", component: ForbiddenView },
    {
      path: "/",
      component: AdminLayout,
      meta: { requiresAuth: true },
      children: [
        { path: "", redirect: "/dashboard" },
        { path: "dashboard", component: DashboardView },
        { path: "markets", component: MarketsView },
        { path: "instruments", component: InstrumentsView },
        { path: "strategies", component: StrategiesView },
        { path: "audit", component: AuditView },
        { path: "workflows", component: WorkflowsView },
        { path: "compliance/exports", component: ComplianceExportsView }
      ]
    }
  ]
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.requiresAuth && !auth.isAuthenticated) return "/login"
  if (to.meta.guestOnly && auth.isAuthenticated) return "/dashboard"
})

export default router
EOF

cat > apps/web-admin/src/components/StatusBadge.vue <<'EOF'
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
EOF

cat > apps/web-admin/src/components/DataTable.vue <<'EOF'
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
EOF

cat > apps/web-admin/src/components/PageHeader.vue <<'EOF'
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
EOF

cat > apps/web-admin/src/layouts/AdminLayout.vue <<'EOF'
<template>
  <div style="display:grid;grid-template-columns:240px 1fr;min-height:100vh;">
    <aside style="padding:18px;border-right:1px solid #ddd;background:#fafafa;">
      <h2 style="margin-top:0;">Admin</h2>
      <nav style="display:grid;gap:10px;">
        <router-link to="/dashboard">Dashboard</router-link>
        <router-link to="/markets">Markets</router-link>
        <router-link to="/instruments">Instruments</router-link>
        <router-link to="/strategies">Strategies</router-link>
        <router-link to="/workflows">Workflows</router-link>
        <router-link to="/compliance/exports">Compliance Exports</router-link>
        <router-link to="/audit">Audit</router-link>
      </nav>
    </aside>
    <main style="padding:20px;">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:18px;">
        <div>Trading Platform Admin</div>
        <button @click="logout">Logout</button>
      </div>
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from "vue-router"
import { useAuthStore } from "../stores/auth"
const router = useRouter()
const auth = useAuthStore()
function logout() {
  auth.logout()
  router.push("/login")
}
</script>
EOF

cat > apps/web-admin/src/views/LoginView.vue <<'EOF'
<template>
  <div style="max-width:380px;margin:80px auto;">
    <h1>Admin Login</h1>
    <form @submit.prevent="submit" style="display:grid;gap:12px;">
      <div><label>Email</label><input v-model="email" type="email" style="width:100%;padding:10px;" /></div>
      <div><label>Password</label><input v-model="password" type="password" style="width:100%;padding:10px;" /></div>
      <button type="submit">Login</button>
      <p v-if="error" style="color:#b91c1c;">{{ error }}</p>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue"
import { useRouter } from "vue-router"
import { useAuthStore } from "../stores/auth"
const router = useRouter()
const auth = useAuthStore()
const email = ref("admin@example.com")
const password = ref("admin")
const error = ref("")
async function submit() {
  error.value = ""
  try {
    await auth.login(email.value, password.value)
    router.push("/dashboard")
  } catch {
    error.value = "Login failed"
  }
}
</script>
EOF

cat > apps/web-admin/src/views/ForbiddenView.vue <<'EOF'
<template><div><h1>Forbidden</h1><p>You do not have access to this page.</p></div></template>
EOF

cat > apps/web-admin/src/views/DashboardView.vue <<'EOF'
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
EOF

cat > apps/web-admin/src/views/MarketsView.vue <<'EOF'
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
EOF

cat > apps/web-admin/src/views/InstrumentsView.vue <<'EOF'
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
EOF

cat > apps/web-admin/src/views/StrategiesView.vue <<'EOF'
<template><div><PageHeader title="Strategies" subtitle="Registered strategies" /><DataTable :columns="columns" :rows="rows" id-field="id" /></div></template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import PageHeader from "../components/PageHeader.vue"
import DataTable from "../components/DataTable.vue"
import { fetchStrategies } from "../api/strategies"
const rows = ref<any[]>([])
const columns = [
  { key: "code", label: "Code" },
  { key: "name", label: "Name" },
  { key: "type", label: "Type" },
  { key: "status", label: "Status" }
]
onMounted(async () => { rows.value = await fetchStrategies() })
</script>
EOF

cat > apps/web-admin/src/views/AuditView.vue <<'EOF'
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
EOF

cat > apps/web-admin/src/views/WorkflowsView.vue <<'EOF'
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
EOF

cat > apps/web-admin/src/views/ComplianceExportsView.vue <<'EOF'
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
EOF

cat > apps/web-admin/playwright.config.ts <<'EOF'
import { defineConfig } from "@playwright/test"
export default defineConfig({ testDir: "./tests/e2e", use: { baseURL: "http://localhost:3000" } })
EOF

cat > apps/web-admin/tests/e2e/auth.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"

test("admin login page loads", async ({ page }) => {
  await page.goto("/login")
  await expect(page.getByText("Admin Login")).toBeVisible()
})
EOF

cat > apps/web-ops/package.json <<'EOF'
{
  "name": "web-ops",
  "private": true,
  "version": "0.1.0",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 3000",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0 --port 3000",
    "test:e2e": "playwright test"
  },
  "dependencies": {
    "axios": "^1.8.0",
    "pinia": "^3.0.1",
    "vue": "^3.5.13",
    "vue-router": "^4.5.0"
  },
  "devDependencies": {
    "@playwright/test": "^1.54.1",
    "@vitejs/plugin-vue": "^5.2.1",
    "typescript": "^5.7.3",
    "vite": "^6.1.0"
  }
}
EOF

cat > apps/web-ops/vite.config.ts <<'EOF'
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"

export default defineConfig({
  plugins: [vue()]
})
EOF

cat > apps/web-ops/src/main.ts <<'EOF'
import { createApp } from "vue"
import { createPinia } from "pinia"
import App from "./App.vue"
import router from "./router"

createApp(App).use(createPinia()).use(router).mount("#app")
EOF

cat > apps/web-ops/src/App.vue <<'EOF'
<template>
  <router-view />
</template>
EOF

cat > apps/web-ops/src/api/http.ts <<'EOF'
import axios from "axios"

export const http = axios.create()

http.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token")
  if (token) {
    config.headers = config.headers || {}
    config.headers.Authorization = `Bearer ${token}`
  }
  config.headers = config.headers || {}
  config.headers["X-Correlation-ID"] = crypto.randomUUID()
  return config
})
EOF

cat > apps/web-ops/src/api/auth.ts <<'EOF'
import { http } from "./http"
export async function loginRequest(payload: { email: string; password: string }) {
  const { data } = await http.post("http://localhost:8001/api/auth/login", payload)
  return data
}
EOF

cat > apps/web-ops/src/api/orders.ts <<'EOF'
import { http } from "./http"
export async function fetchOrders() {
  const { data } = await http.get("http://localhost:8005/api/orders")
  return data
}
export async function submitOrder(payload: any) {
  const { data } = await http.post("http://localhost:8005/api/orders/submit", payload)
  return data
}
export async function fetchOrderDetail(id: string) {
  const { data } = await http.get(`http://localhost:8005/api/orders/${id}`)
  return data
}
EOF

cat > apps/web-ops/src/api/positions.ts <<'EOF'
import { http } from "./http"
export async function fetchPositions() {
  const { data } = await http.get("http://localhost:8008/api/positions")
  return data
}
EOF

cat > apps/web-ops/src/api/risk.ts <<'EOF'
import { http } from "./http"
export async function fetchBreaches() {
  const { data } = await http.get("http://localhost:8006/api/risk/breaches")
  return data
}
export async function fetchKillSwitches() {
  const { data } = await http.get("http://localhost:8006/api/risk/kill-switches")
  return data
}
export async function createKillSwitch(payload: any) {
  const { data } = await http.post("http://localhost:8006/api/risk/kill-switches", payload)
  return data
}
export async function fetchDrawdownTrackers() {
  const { data } = await http.get("http://localhost:8006/api/risk/drawdown-trackers")
  return data
}
EOF

cat > apps/web-ops/src/api/execution.ts <<'EOF'
import { http } from "./http"
export async function fetchExecutionQuality() {
  const { data } = await http.get("http://localhost:8007/api/execution/quality-metrics")
  return data
}
EOF

cat > apps/web-ops/src/api/signals.ts <<'EOF'
import { http } from "./http"
export async function fetchSignals() {
  const { data } = await http.get("http://localhost:8012/api/signals")
  return data
}
EOF

cat > apps/web-ops/src/api/targets.ts <<'EOF'
import { http } from "./http"
export async function fetchTargets() {
  const { data } = await http.get("http://localhost:8013/api/targets")
  return data
}
EOF

cat > apps/web-ops/src/api/runtime.ts <<'EOF'
import { http } from "./http"
export async function runSampleRuntime(payload: any) {
  const { data } = await http.post("http://localhost:8011/api/runtime/run-sample", payload)
  return data
}
EOF

cat > apps/web-ops/src/stores/auth.ts <<'EOF'
import { defineStore } from "pinia"
import { loginRequest } from "../api/auth"

export const useAuthStore = defineStore("auth", {
  state: () => ({
    token: localStorage.getItem("access_token") || "",
    user: JSON.parse(localStorage.getItem("auth_user") || "null") as null | Record<string, any>,
    roles: JSON.parse(localStorage.getItem("auth_roles") || "[]") as string[]
  }),
  getters: { isAuthenticated: (state) => !!state.token },
  actions: {
    async login(email: string, password: string) {
      const data = await loginRequest({ email, password })
      this.token = data.access_token
      this.user = data.user
      this.roles = data.roles || []
      localStorage.setItem("access_token", this.token)
      localStorage.setItem("auth_user", JSON.stringify(this.user))
      localStorage.setItem("auth_roles", JSON.stringify(this.roles))
    },
    logout() {
      this.token = ""
      this.user = null
      this.roles = []
      localStorage.removeItem("access_token")
      localStorage.removeItem("auth_user")
      localStorage.removeItem("auth_roles")
    }
  }
})
EOF

cat > apps/web-ops/src/router/index.ts <<'EOF'
import { createRouter, createWebHistory } from "vue-router"
import LoginView from "../views/LoginView.vue"
import OpsLayout from "../layouts/OpsLayout.vue"
import DashboardView from "../views/DashboardView.vue"
import OrdersView from "../views/OrdersView.vue"
import OrderDetailView from "../views/OrderDetailView.vue"
import PositionsView from "../views/PositionsView.vue"
import RiskBreachesView from "../views/RiskBreachesView.vue"
import KillSwitchesView from "../views/KillSwitchesView.vue"
import ExecutionQualityView from "../views/ExecutionQualityView.vue"
import SignalsView from "../views/SignalsView.vue"
import TargetsView from "../views/TargetsView.vue"
import { useAuthStore } from "../stores/auth"

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/login", component: LoginView, meta: { guestOnly: true } },
    {
      path: "/",
      component: OpsLayout,
      meta: { requiresAuth: true },
      children: [
        { path: "", redirect: "/dashboard" },
        { path: "dashboard", component: DashboardView },
        { path: "orders", component: OrdersView },
        { path: "orders/:id", component: OrderDetailView },
        { path: "positions", component: PositionsView },
        { path: "risk/breaches", component: RiskBreachesView },
        { path: "risk/kill-switches", component: KillSwitchesView },
        { path: "executions/quality", component: ExecutionQualityView },
        { path: "signals", component: SignalsView },
        { path: "targets", component: TargetsView }
      ]
    }
  ]
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.requiresAuth && !auth.isAuthenticated) return "/login"
  if (to.meta.guestOnly && auth.isAuthenticated) return "/dashboard"
})

export default router
EOF

cat > apps/web-ops/src/layouts/OpsLayout.vue <<'EOF'
<template>
  <div style="display:grid;grid-template-columns:240px 1fr;min-height:100vh;">
    <aside style="padding:18px;border-right:1px solid #ddd;background:#fafafa;">
      <h2 style="margin-top:0;">Ops</h2>
      <nav style="display:grid;gap:10px;">
        <router-link to="/dashboard">Dashboard</router-link>
        <router-link to="/signals">Signals</router-link>
        <router-link to="/targets">Targets</router-link>
        <router-link to="/orders">Orders</router-link>
        <router-link to="/positions">Positions</router-link>
        <router-link to="/executions/quality">Execution Quality</router-link>
        <router-link to="/risk/breaches">Breaches</router-link>
        <router-link to="/risk/kill-switches">Kill Switches</router-link>
      </nav>
    </aside>
    <main style="padding:20px;">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:18px;">
        <div>Trading Platform Ops</div>
        <button @click="logout">Logout</button>
      </div>
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from "vue-router"
import { useAuthStore } from "../stores/auth"
const router = useRouter()
const auth = useAuthStore()
function logout() {
  auth.logout()
  router.push("/login")
}
</script>
EOF

cat > apps/web-ops/src/views/LoginView.vue <<'EOF'
<template>
  <div style="max-width:380px;margin:80px auto;">
    <h1>Ops Login</h1>
    <form @submit.prevent="submit" style="display:grid;gap:12px;">
      <div><label>Email</label><input v-model="email" type="email" style="width:100%;padding:10px;" /></div>
      <div><label>Password</label><input v-model="password" type="password" style="width:100%;padding:10px;" /></div>
      <button type="submit">Login</button>
      <p v-if="error" style="color:#b91c1c;">{{ error }}</p>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue"
import { useRouter } from "vue-router"
import { useAuthStore } from "../stores/auth"
const router = useRouter()
const auth = useAuthStore()
const email = ref("admin@example.com")
const password = ref("admin")
const error = ref("")
async function submit() {
  error.value = ""
  try {
    await auth.login(email.value, password.value)
    router.push("/dashboard")
  } catch {
    error.value = "Login failed"
  }
}
</script>
EOF

cat > apps/web-ops/src/views/DashboardView.vue <<'EOF'
<template>
  <div>
    <h1>Ops Dashboard</h1>
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:16px;">
      <div style="padding:16px;border:1px solid #ddd;border-radius:8px;">Orders: {{ stats.orders }}</div>
      <div style="padding:16px;border:1px solid #ddd;border-radius:8px;">Positions: {{ stats.positions }}</div>
      <div style="padding:16px;border:1px solid #ddd;border-radius:8px;">Breaches: {{ stats.breaches }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive } from "vue"
import { fetchOrders } from "../api/orders"
import { fetchPositions } from "../api/positions"
import { fetchBreaches } from "../api/risk"
const stats = reactive({ orders: 0, positions: 0, breaches: 0 })
onMounted(async () => {
  stats.orders = (await fetchOrders()).length
  stats.positions = (await fetchPositions()).length
  stats.breaches = (await fetchBreaches()).length
})
</script>
EOF

cat > apps/web-ops/src/views/OrdersView.vue <<'EOF'
<template>
  <div>
    <h1>Orders</h1>
    <form @submit.prevent="submit" style="display:grid;gap:10px;max-width:480px;margin-bottom:20px;">
      <input v-model="form.instrument_id" placeholder="Instrument ID" />
      <input v-model="form.venue_id" placeholder="Venue ID" />
      <select v-model="form.side"><option value="buy">buy</option><option value="sell">sell</option></select>
      <input v-model="form.quantity" placeholder="Quantity" />
      <input v-model="form.execution_price" placeholder="Execution Price" />
      <button type="submit">Submit Order</button>
    </form>
    <pre v-if="lastResponse">{{ lastResponse }}</pre>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Instrument</th><th>Side</th><th>Type</th><th>Quantity</th><th>Status</th><th>Open</th></tr></thead>
      <tbody>
        <tr v-for="row in rows" :key="row.id">
          <td>{{ row.id }}</td><td>{{ row.instrument_id }}</td><td>{{ row.side }}</td><td>{{ row.order_type }}</td><td>{{ row.quantity }}</td><td>{{ row.intent_status }}</td><td><router-link :to="`/orders/${row.id}`">Detail</router-link></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchOrders, submitOrder } from "../api/orders"
const rows = ref<any[]>([])
const lastResponse = ref("")
const form = ref({ instrument_id: "", venue_id: "", side: "buy", quantity: "1000", execution_price: "1.0850" })
async function load() { rows.value = await fetchOrders() }
async function submit() {
  const data = await submitOrder({ instrument_id: form.value.instrument_id, side: form.value.side, order_type: "market", quantity: form.value.quantity, tif: "IOC", venue_id: form.value.venue_id, execution_price: form.value.execution_price })
  lastResponse.value = JSON.stringify(data, null, 2)
  await load()
}
onMounted(load)
</script>
EOF

cat > apps/web-ops/src/views/OrderDetailView.vue <<'EOF'
<template><div><h1>Order Detail</h1><pre v-if="detail">{{ JSON.stringify(detail, null, 2) }}</pre></div></template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { useRoute } from "vue-router"
import { fetchOrderDetail } from "../api/orders"
const route = useRoute()
const detail = ref<any>(null)
onMounted(async () => { detail.value = await fetchOrderDetail(String(route.params.id)) })
</script>
EOF

cat > apps/web-ops/src/views/PositionsView.vue <<'EOF'
<template>
  <div>
    <h1>Positions</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>Instrument</th><th>Net Quantity</th><th>Average Price</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.instrument_id }}</td><td>{{ row.net_quantity }}</td><td>{{ row.avg_price }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchPositions } from "../api/positions"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchPositions() })
</script>
EOF

cat > apps/web-ops/src/views/RiskBreachesView.vue <<'EOF'
<template>
  <div>
    <h1>Risk Breaches</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Breach Type</th><th>Severity</th><th>Status</th><th>Detected</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.breach_type }}</td><td>{{ row.severity }}</td><td>{{ row.status }}</td><td>{{ row.detected_at }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchBreaches } from "../api/risk"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchBreaches() })
</script>
EOF

cat > apps/web-ops/src/views/KillSwitchesView.vue <<'EOF'
<template>
  <div>
    <h1>Kill Switches</h1>
    <button @click="createDemo">Create Global Kill Switch</button>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;margin-top:16px;">
      <thead><tr><th>ID</th><th>Scope Type</th><th>Scope ID</th><th>Action</th><th>Status</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.scope_type }}</td><td>{{ row.scope_id }}</td><td>{{ row.switch_action }}</td><td>{{ row.status }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { createKillSwitch, fetchKillSwitches } from "../api/risk"
const rows = ref<any[]>([])
async function load() { rows.value = await fetchKillSwitches() }
async function createDemo() {
  await createKillSwitch({ scope_type: "global", switch_action: "reject_new_orders", reason: "UI test" })
  await load()
}
onMounted(load)
</script>
EOF

cat > apps/web-ops/src/views/ExecutionQualityView.vue <<'EOF'
<template>
  <div>
    <h1>Execution Quality</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Broker Order</th><th>Slippage Bps</th><th>Fee Amount</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.broker_order_id }}</td><td>{{ row.slippage_bps }}</td><td>{{ row.total_fee_amount }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchExecutionQuality } from "../api/execution"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchExecutionQuality() })
</script>
EOF

cat > apps/web-ops/src/views/SignalsView.vue <<'EOF'
<template>
  <div>
    <h1>Signals</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Deployment</th><th>Instrument</th><th>Direction</th><th>Strength</th><th>Confidence</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.strategy_deployment_id }}</td><td>{{ row.instrument_id }}</td><td>{{ row.direction }}</td><td>{{ row.strength }}</td><td>{{ row.confidence }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchSignals } from "../api/signals"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchSignals() })
</script>
EOF

cat > apps/web-ops/src/views/TargetsView.vue <<'EOF'
<template>
  <div>
    <h1>Portfolio Targets</h1>
    <table border="1" cellpadding="8" style="width:100%;border-collapse:collapse;">
      <thead><tr><th>ID</th><th>Instrument</th><th>Target Quantity</th><th>Delta Quantity</th><th>Correlation ID</th></tr></thead>
      <tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.id }}</td><td>{{ row.instrument_id }}</td><td>{{ row.target_quantity }}</td><td>{{ row.delta_quantity }}</td><td>{{ row.correlation_id }}</td></tr></tbody>
    </table>
  </div>
</template>
<script setup lang="ts">
import { onMounted, ref } from "vue"
import { fetchTargets } from "../api/targets"
const rows = ref<any[]>([])
onMounted(async () => { rows.value = await fetchTargets() })
</script>
EOF

cat > apps/web-ops/playwright.config.ts <<'EOF'
import { defineConfig } from "@playwright/test"
export default defineConfig({ testDir: "./tests/e2e", use: { baseURL: "http://localhost:3001" } })
EOF

cat > apps/web-ops/tests/e2e/order-flow.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"

test("ops login page loads", async ({ page }) => {
  await page.goto("/login")
  await expect(page.getByText("Ops Login")).toBeVisible()
})
EOF

cat > apps/web-admin/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]
EOF

cat > apps/web-ops/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]
EOF

echo "Vue admin + ops UI bootstrap applied."
echo "Next: docker compose build web-admin web-ops && docker compose up -d web-admin web-ops"
