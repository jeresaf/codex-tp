<template>
  <div style="display: grid; grid-template-columns: 220px 1fr; min-height: 100vh;">
    <aside style="padding: 16px; border-right: 1px solid #ddd;"><h3>Ops</h3><nav style="display: grid; gap: 8px;"><router-link to="/orders">Orders</router-link><router-link to="/positions">Positions</router-link></nav></aside>
    <main style="padding: 16px;"><router-view /></main>
  </div>
</template>
