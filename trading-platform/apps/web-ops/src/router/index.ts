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
