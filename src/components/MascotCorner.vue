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
  margin: 0 0 6px auto;
  pointer-events: none;
}

@media (max-width: 600px) {
  .dl-mascot-corner {
    width: 56px;
    height: 56px;
    margin-bottom: 2px;
  }
}

@media (orientation: landscape) and (max-height: 540px) {
  .dl-mascot-corner {
    width: 44px;
    height: 44px;
    margin-bottom: 0;
  }
}
</style>
