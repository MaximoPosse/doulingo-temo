<template>
  <router-view />
</template>

<script setup>
import { onMounted } from 'vue'

import { initAuth } from '@/composables/useAuth'

// Al abrir la app se restaura la sesión guardada en el dispositivo
// (invitado o cuenta permanente).
onMounted(() => {
  initAuth()
})
</script>
