<template>
  <header class="dl-header">
    <div class="dl-header__inner">
      <router-link to="/" class="dl-brand">
        <q-img
          :src="usagiImg"
          alt="Usagi, la mascota de Doulingo"
          class="dl-brand__mascot"
        />
        <span class="dl-brand__name">Doulingo</span>
      </router-link>

      <nav class="dl-header__nav">
        <router-link
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          class="dl-nav-link"
          :exact="item.exact"
        >
          {{ item.label }}
        </router-link>
      </nav>

      <q-btn
        no-caps
        unelevated
        class="dl-btn-main dl-btn-main--small"
        label="Empezar"
        :to="{ name: 'cursos' }"
      />
    </div>
  </header>
</template>

<script setup>
import usagiImg from '@/assets/usagi.webp'

const navItems = [
  { label: 'Inicio', to: '/', exact: true },
  { label: 'Cursos', to: { name: 'cursos' }, exact: false }
]
</script>

<style lang="scss" scoped>
.dl-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: #ffffff;
  border-bottom: 2px solid $dl-gray;

  &__inner {
    max-width: 1100px;
    margin: 0 auto;
    padding: 10px 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
  }

  &__nav {
    display: flex;
    align-items: center;
    gap: 8px;
  }
}

.dl-brand {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  text-decoration: none;

  &__mascot {
    width: 42px;
    height: 42px;
    object-fit: contain;
  }

  &__name {
    font-size: 26px;
    font-weight: 800;
    letter-spacing: 0.5px;
    color: $dl-green-dark;
  }
}

.dl-nav-link {
  text-decoration: none;
  color: #6b6b6b;
  font-weight: 800;
  font-size: 15px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  padding: 8px 14px;
  border-radius: 12px;
  transition:
    background 0.15s ease,
    color 0.15s ease;

  &:hover {
    background: #f0f4f0;
    color: $dl-green-dark;
  }

  &.router-link-active {
    color: $dl-green-dark;
    background: #e9f7e2;
  }
}

@media (max-width: 640px) {
  .dl-header__inner {
    flex-wrap: wrap;
    justify-content: center;
    padding: 10px 12px;
  }
}
</style>
