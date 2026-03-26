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
