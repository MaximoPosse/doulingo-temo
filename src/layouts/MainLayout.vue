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
          <q-btn
            flat
            no-caps
            class="dl-nav__account"
            :label="hasSession ? publicName : 'Acceder'"
            icon="badge"
            :to="hasSession ? { name: 'perfil' } : { name: 'acceso' }"
          />
        </nav>
      </q-toolbar>

      <!-- Aviso: se entró con otra cuenta y los historiales no se fusionan -->
      <q-banner v-if="accountChanged" rounded class="dl-account-banner">
        <q-icon name="swap_horiz" size="20px" color="orange" />
        <span>
          Entraste con una cuenta distinta a la que se usaba en este
          dispositivo. Los historiales <strong>no se fusionan</strong> de forma
          automática: el avance anterior sigue guardado en su cuenta.
        </span>
        <q-btn
          flat
          dense
          no-caps
          label="Entendido"
          class="dl-account-banner__close"
          @click="dismissAccountChanged"
        />
      </q-banner>
    </q-header>

    <q-page-container>
      <!-- :key fuerza a remontar la página cuando cambian los params de ruta
           (p. ej. pasar de una lección a la siguiente). Sin esto, Vue reutiliza
           la instancia y no vuelve a consultar los datos. -->
      <router-view :key="$route.fullPath" />
    </q-page-container>
  </q-layout>
</template>

<script setup>
import { computed } from 'vue'

import usagiImg from '@/assets/usagi.webp'
import { useAuth } from '@/composables/useAuth'

const { session, publicName, accountChanged, dismissAccountChanged } = useAuth()
const hasSession = computed(() => !!session.value)
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

.dl-nav__account {
  color: #58a700 !important;
}

.dl-account-banner {
  background: #fff8e1;
  color: #6b6b6b;
  font-size: 13px;
}

.dl-account-banner__close {
  color: #58a700;
  font-weight: 700;
}
</style>
