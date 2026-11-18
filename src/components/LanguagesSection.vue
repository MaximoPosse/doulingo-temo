<template>
  <section class="dl-langs">
    <div class="dl-langs__inner">
      <h2 class="dl-section-title">Elegí tu lenguaje</h2>
      <p class="dl-langs__lead">
        Seis lenguajes para empezar desde cero. Cada curso tiene su camino de
        unidades, lecciones y preguntas con corrección al instante.
      </p>

      <div class="dl-langs__grid">
        <component
          :is="lang.available ? 'router-link' : 'div'"
          v-for="lang in languages"
          :key="lang.slug"
          :to="
            lang.available
              ? { name: 'curso', params: { slug: lang.slug } }
              : undefined
          "
          class="dl-lang"
          :class="{ 'dl-lang--soon': !lang.available }"
        >
          <span
            class="dl-lang__logo"
            :style="{ background: lang.color, color: lang.ink }"
            aria-hidden="true"
          >
            {{ lang.code }}
          </span>
          <span class="dl-lang__body">
            <span class="dl-lang__name">{{ lang.name }}</span>
            <span class="dl-lang__tag">{{ lang.tag }}</span>
          </span>
          <span class="dl-lang__state">
            <q-icon
              :name="lang.available ? 'chevron_right' : 'schedule'"
              size="22px"
            />
            <span class="dl-lang__state-text">{{
              lang.available ? 'Disponible' : 'Próximamente'
            }}</span>
          </span>
        </component>
      </div>

      <div class="dl-langs__cta">
        <q-btn
          no-caps
          unelevated
          class="dl-btn-main dl-btn-main--big"
          label="Ver todos los cursos"
          :to="{ name: 'cursos' }"
        />
      </div>
    </div>
  </section>
</template>

<script setup>
import { computed } from 'vue'

import { getCourses } from '@/data/courseRepository'
import { useRemoteData } from '@/composables/useRemoteData'

// Los seis lenguajes se muestran siempre. Cada uno figura como "Disponible"
// cuando el curso ya está publicado en la base de datos.
const catalog = [
  {
    slug: 'javascript',
    name: 'JavaScript',
    code: 'JS',
    tag: 'Web interactiva',
    color: '#f7df1e',
    ink: '#3c3c3c'
  },
  {
    slug: 'python',
    name: 'Python',
    code: 'Py',
    tag: 'Datos, IA y automatización',
    color: '#3776ab',
    ink: '#ffffff'
  },
  {
    slug: 'php',
    name: 'PHP',
    code: 'PHP',
    tag: 'Sitios web dinámicos',
    color: '#777bb4',
    ink: '#ffffff'
  },
  {
    slug: 'java',
    name: 'Java',
    code: 'Jv',
    tag: 'Aplicaciones y Android',
    color: '#f89820',
    ink: '#3c3c3c'
  },
  {
    slug: 'csharp',
    name: 'C#',
    code: 'C#',
    tag: 'Apps y videojuegos',
    color: '#9b4f96',
    ink: '#ffffff'
  },
  {
    slug: 'cpp',
    name: 'C++',
    code: 'C++',
    tag: 'Alto rendimiento',
    color: '#00599c',
    ink: '#ffffff'
  }
]

const { data } = useRemoteData(getCourses)

const languages = computed(() => {
  const published = new Set((data.value ?? []).map(course => course.slug))
  return catalog.map(lang => ({ ...lang, available: published.has(lang.slug) }))
})
</script>

<style lang="scss" scoped>
.dl-langs {
  background: $dl-surface;
  padding: 56px 0;

  &__inner {
    max-width: 1100px;
    margin: 0 auto;
    padding: 0 20px;
    text-align: center;
  }

  &__lead {
    max-width: 620px;
    margin: 0 auto 28px;
    color: $dl-ink;
    font-size: 17px;
    line-height: 1.5;
  }

  &__grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(300px, 100%), 1fr));
    gap: 14px;
    text-align: left;
  }

  &__cta {
    margin-top: 28px;
  }
}

.dl-lang {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 16px;
  border: 2px solid $dl-gray;
  border-radius: 16px;
  background: $dl-surface;
  color: inherit;
  text-decoration: none;
  box-shadow: 0 4px 0 #2a2a2a;
  transition:
    transform 0.12s ease,
    border-color 0.12s ease;

  &:hover {
    border-color: $dl-green;
    transform: translateY(-2px);
  }

  &--soon {
    opacity: 0.75;
    box-shadow: none;

    &:hover {
      border-color: $dl-gray;
      transform: none;
    }
  }

  &__logo {
    flex: 0 0 auto;
    display: grid;
    place-items: center;
    width: 54px;
    height: 54px;
    border-radius: 14px;
    font-size: 19px;
    font-weight: 800;
    letter-spacing: -0.5px;
  }

  &__body {
    flex: 1 1 auto;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  &__name {
    font-size: 19px;
    font-weight: 800;
    color: $dl-ink-dark;
  }

  &__tag {
    font-size: 14px;
    color: $dl-ink;
    overflow-wrap: anywhere;
  }

  &__state {
    flex: 0 0 auto;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 12px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.3px;
    color: $dl-green-dark;
  }

  &--soon &__state {
    color: #a3a3a3;
  }
}

@media (max-width: 420px) {
  .dl-langs {
    padding: 40px 0;

    &__inner {
      padding: 0 16px;
    }
  }

  .dl-lang {
    padding: 12px;
    gap: 10px;

    &__logo {
      width: 46px;
      height: 46px;
      font-size: 16px;
    }

    &__name {
      font-size: 17px;
    }

    // En pantallas muy angostas solo se muestra el ícono de estado.
    &__state-text {
      display: none;
    }
  }
}
</style>
