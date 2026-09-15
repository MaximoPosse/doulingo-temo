<template>
  <div class="fullscreen bg-white flex flex-center" style="background: #ffffff">
    <div class="text-center q-pa-md">
      <img
        :src="usagiImg"
        alt="Usagi perdida"
        style="width: 160px; height: 160px; object-fit: contain"
      />
      <h2
        class="q-mb-sm"
        style="font-weight: 800; color: #3c3c3c; font-size: 34px"
        >¡Ups! Página no encontrada</h2
      >
      <p class="q-mb-lg" style="color: #6b6b6b; font-size: 17px">
        Parece que Usagi se perdió buscando lo que querías. Vuelve al inicio.
      </p>

      <q-btn
        unelevated
        no-caps
        size="lg"
        class="dl-btn-main dl-btn-main--big"
        to="/"
        label="Volver al inicio"
      />
    </div>
  </div>
</template>

<script setup>
import usagiImg from '@/assets/usagi.webp'
</script>
