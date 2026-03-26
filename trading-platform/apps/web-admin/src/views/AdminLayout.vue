<template>
  <div style="display: grid; grid-template-columns: 220px 1fr; min-height: 100vh;">
    <aside style="padding: 16px; border-right: 1px solid #ddd;">
      <h3>Admin</h3>
      <nav style="display: grid; gap: 8px;">
        <router-link to="/markets">Markets</router-link>
        <router-link to="/instruments">Instruments</router-link>
        <router-link to="/strategies">Strategies</router-link>
        <router-link to="/audit">Audit</router-link>
      </nav>
    </aside>
    <main style="padding: 16px;"><router-view /></main>
  </div>
</template>
