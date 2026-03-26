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
