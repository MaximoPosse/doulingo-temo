<template>
  <q-layout view="hHh lpr fFf">
    <q-header>
      <q-toolbar class="dl-bar">
        <router-link to="/" class="dl-brand">
          <img
            :src="logoImg"
            alt="Logo de CodeLingua"
            class="dl-brand__mascot"
          />
          <span class="dl-brand__name">CodeLingua</span>
        </router-link>

        <nav class="dl-nav">
          <q-btn flat no-caps label="Inicio" to="/" />
          <q-btn flat no-caps label="Cursos" to="/cursos" />
          <q-btn flat no-caps label="Expo" to="/expo" />
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

    <!-- Flecha para volver arriba: aparece al bajar -->
    <q-page-scroller
      v-if="mostrarFlecha"
      position="bottom-right"
      :scroll-offset="300"
      :offset="[16, 16]"
      :duration="350"
    >
      <q-btn
        fab
        color="primary"
        icon="keyboard_arrow_up"
        aria-label="Volver arriba"
        class="dl-to-top"
      />
    </q-page-scroller>
  </q-layout>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import logoImg from '@/assets/logo.webp'
import { useAuth } from '@/composables/useAuth'

const { session, publicName, accountChanged, dismissAccountChanged } = useAuth()
const hasSession = computed(() => !!session.value)

// En el minijuego y en las preguntas la flecha taparía botones: no se muestra.
const route = useRoute()
const mostrarFlecha = computed(
  () => !['minijuego', 'leccion', 'desafio'].includes(route.name)
)
</script>

<style scoped>
.dl-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  row-gap: 2px;
  /* En el APK la app ocupa toda la pantalla: se deja lugar a la barra de
     estado y a las muescas (viewport-fit=cover). */
  padding: 6px max(20px, env(safe-area-inset-right)) 6px
    max(20px, env(safe-area-inset-left));
  padding-top: calc(6px + env(safe-area-inset-top));
  background: $dl-surface;
  color: #f5f5f5;
  border-bottom: 2px solid $dl-gray;
}

.dl-brand {
  display: inline-flex;
  text-decoration: none;
  align-items: center;
  gap: 8px;
}

.dl-brand__mascot {
  width: 52px;
  height: 52px;
  object-fit: contain;
}

.dl-brand__name {
  font-size: 24px;
  font-weight: 800;
  letter-spacing: 0.5px;
  color: #ffd24d;
}

.dl-nav {
  display: flex;
  align-items: center;
  gap: 6px;
}

.dl-nav .q-btn {
  font-weight: 700;
  color: #bdbdbd;
  min-height: 40px;
}

.dl-nav__account {
  max-width: 220px;
}

.dl-nav .q-btn :deep(.q-btn__content) {
  min-width: 0;
  flex-wrap: nowrap;
}

.dl-nav .q-btn :deep(.block) {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Celulares: el logo arriba y los cuatro accesos repartidos en una fila. */
@media (max-width: 600px) {
  .dl-bar {
    justify-content: center;
    padding-left: max(10px, env(safe-area-inset-left));
    padding-right: max(10px, env(safe-area-inset-right));
  }

  .dl-brand__mascot {
    width: 40px;
    height: 40px;
  }

  .dl-brand__name {
    font-size: 21px;
  }

  .dl-nav {
    width: 100%;
    gap: 2px;
    justify-content: space-between;
  }

  .dl-nav .q-btn {
    flex: 1 1 0;
    min-width: 0;
    padding: 0 4px;
    font-size: 13px;
  }

  .dl-nav__account {
    flex: 2.6 1 0;
    max-width: none;
  }
}

@media (max-width: 360px) {
  .dl-nav .q-btn {
    font-size: 12px;
  }

  .dl-nav__account :deep(.q-icon) {
    display: none;
  }
}

.dl-nav__account {
  color: #ffd24d !important;
}

.dl-to-top {
  box-shadow: 0 4px 0 $dl-yellow-shadow;
  /* En el APK se evita la barra de gestos del celular. */
  margin-bottom: env(safe-area-inset-bottom);
}

.dl-account-banner {
  background: #211b0b;
  color: #bdbdbd;
  font-size: 13px;
}

.dl-account-banner__close {
  color: #ffd24d;
  font-weight: 700;
}
</style>
