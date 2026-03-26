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
