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
