<template>
  <q-layout view="hh rr fff">
    <q-header>
      <q-toolbar class="dl-bar">
        <div class="dl-brand">
          <img
            :src="usagiImg"
            alt="Usagi, la mascota de Doulingo"
            class="dl-brand__mascot"
          />
          <span class="dl-brand__name">Arabytes</span>
        </div>

        <nav class="dl-nav">
          <q-btn flat no-caps label="Inicio" to="/" />
          <q-btn flat no-caps label="Cursos" to="/cursos" />
        </nav>
      </q-toolbar>
    </q-header>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup>
import usagiImg from '@/assets/usagi.webp'
</script>

<style scoped>
.dl-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 20px;
  background: #ffffff;
  color: #3c3c3c;
  border-bottom: 2px solid #e5e5e5;
}

.dl-brand {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.dl-brand__mascot {
  width: 42px;
  height: 42px;
  object-fit: contain;
}

.dl-brand__name {
  font-size: 24px;
  font-weight: 800;
  letter-spacing: 0.5px;
  color: #58a700;
}

.dl-nav {
  display: flex;
  align-items: center;
  gap: 6px;
}

.dl-nav .q-btn {
  font-weight: 700;
  color: #6b6b6b;
}
</style>
