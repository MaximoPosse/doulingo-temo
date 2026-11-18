<template>
  <img :src="src" :alt="alt" class="dl-mascot-corner" />
</template>

<script setup>
import { computed } from 'vue'

// Personaje decorativo para la esquina superior de cada pantalla.
const images = import.meta.glob('@/assets/amigos/*.webp', {
  eager: true,
  import: 'default'
})

const props = defineProps({
  name: { type: String, required: true },
  alt: { type: String, default: '' }
})

const src = computed(
  () => images[`/src/assets/amigos/${props.name}.webp`] || ''
)
</script>

<style scoped lang="scss">
.dl-mascot-corner {
  display: block;
  width: 96px;
  height: 96px;
  object-fit: contain;
  background: #ffffff;
  border-radius: 22px;
  padding: 4px;
  margin: 0 0 6px auto;
  pointer-events: none;
}

@media (max-width: 600px) {
  .dl-mascot-corner {
    width: 72px;
    height: 72px;
  }
}
</style>
