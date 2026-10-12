<template>
  <q-page class="dl-page">
    <div class="dl-page__inner">
      <div class="dl-page__head">
        <div>
          <h1 class="dl-page__title">Elige tu curso</h1>
          <p class="dl-page__lead">
            Todos los cursos empiezan desde cero. Completa unidades, resuelve
            ejercicios y construye tu racha con la guía de Usagi.
          </p>
        </div>
        <img :src="usagiImg" alt="Usagi" class="dl-courses__mascot" />
      </div>

      <!-- Cargando -->
      <div v-if="loading" class="dl-states">
        <q-spinner color="primary" size="34px" class="q-mb-sm" />
        <p class="dl-states__text">Cargando los cursos…</p>
      </div>

      <!-- Error de consulta -->
      <div v-else-if="error" class="dl-states">
        <q-icon name="wifi_off" size="44px" color="negative" />
        <h2 class="dl-states__title">No se pudieron cargar los cursos</h2>
        <p class="dl-states__text">{{ error }}</p>
        <q-btn
          no-caps
          unelevated
          color="primary"
          class="q-mt-sm"
          label="Reintentar"
          @click="load"
        />
      </div>

      <!-- Sin cursos disponibles -->
      <q-banner
        v-else-if="courses.length === 0"
        rounded
        class="dl-empty-banner"
      >
        <q-icon name="school" size="22px" color="primary" />
        Todavía no hay cursos disponibles. Volvé más tarde para empezar a
        aprender.
      </q-banner>

      <!-- Listado -->
      <div v-else class="dl-courses__grid">
        <CourseCard
          v-for="course in courses"
          :key="course.id"
          :course="course"
          @select="openCourse"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { getCourses } from '@/data/courseRepository'
import { useRemoteData } from '@/composables/useRemoteData'
import CourseCard from '@/components/CourseCard.vue'
import usagiImg from '@/assets/usagi.webp'

const router = useRouter()

const { data, loading, error, load } = useRemoteData(getCourses)
const courses = computed(() => data.value ?? [])

function openCourse(course) {
  router.push({ name: 'curso', params: { slug: course.slug } })
}
</script>

<style lang="scss" scoped>
.dl-courses {
  &__mascot {
    width: 120px;
    height: 120px;
    object-fit: contain;
  }

  &__grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 20px;
  }
}

.dl-states {
  text-align: center;
  padding: 48px 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;

  &__title {
    font-size: 20px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 4px 0 0;
  }

  &__text {
    font-size: 14px;
    line-height: 1.55;
    color: #6b6b6b;
    margin: 0;
    max-width: 480px;
  }
}

.dl-empty-banner {
  background: #f6fbf4;
  color: $dl-ink;
}
</style>
