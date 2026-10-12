<template>
  <q-page class="dl-page">
    <div class="dl-page__inner">
      <router-link to="/cursos" class="dl-back">
        <q-icon name="arrow_back" size="18px" />
        Volver a cursos
      </router-link>

      <!-- Cargando -->
      <div v-if="loading" class="dl-states">
        <q-spinner color="primary" size="34px" class="q-mb-sm" />
        <p class="dl-states__text">Cargando el curso…</p>
      </div>

      <!-- Error de consulta -->
      <div v-else-if="error" class="dl-states">
        <q-icon name="wifi_off" size="44px" color="negative" />
        <h2 class="dl-states__title">No se pudo cargar el curso</h2>
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

      <!-- Curso no encontrado -->
      <q-banner v-else-if="!course" rounded class="dl-notfound-banner">
        <q-icon name="error_outline" size="22px" color="negative" />
        No encontramos un curso con identificador <strong>{{ slug }}</strong
        >.
      </q-banner>

      <!-- Contenido del curso -->
      <template v-else>
        <div class="dl-course-hero" :style="{ '--course-color': course.color }">
          <span class="dl-course-hero__icon">
            <q-icon :name="course.icon" size="44px" />
          </span>
          <div>
            <div class="dl-course-hero__tags">
              <span class="dl-badge dl-badge--available">
                <q-icon name="check_circle" />
                Disponible
              </span>
              <span class="dl-course-hero__accent">{{ course.level }}</span>
            </div>
            <h1 class="dl-course-hero__title">{{ course.title }}</h1>
            <p class="dl-course-hero__desc">{{ course.description }}</p>
            <div class="dl-course-hero__progress">
              <div class="dl-course-hero__progress-bar">
                <div
                  class="dl-course-hero__progress-fill"
                  :style="{ width: `${overallPct}%` }"
                />
              </div>
              <span class="dl-course-hero__progress-text">
                {{ overallText }}
              </span>
            </div>
          </div>
        </div>

        <h2 class="dl-section-title q-mt-lg">Unidades del curso</h2>
        <p class="dl-page__lead">
          Completa las lecciones de cada unidad para desbloquear la siguiente.
        </p>

        <!-- Sin unidades -->
        <q-banner v-if="units.length === 0" rounded class="dl-empty-banner">
          <q-icon name="construction" size="22px" color="orange" />
          Este curso todavía no tiene unidades publicadas. Volvé más tarde.
        </q-banner>

        <UnitCard
          v-for="(unit, index) in units"
          :key="unit.id"
          :unit="unit"
          :unit-index="index"
          :units="units"
          :class="{ 'dl-course__unit--last': index === units.length - 1 }"
          @select="openUnit"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getCourseBySlug, getUnits } from '@/data/courseRepository'
import { useProgress } from '@/composables/useProgress'
import { useRemoteData } from '@/composables/useRemoteData'
import UnitCard from '@/components/UnitCard.vue'

const route = useRoute()
const router = useRouter()
const { countApprovedLessons } = useProgress()

const slug = computed(() => route.params.slug)

const { data, loading, error, load } = useRemoteData(async () => {
  const course = await getCourseBySlug(slug.value)
  const units = course ? await getUnits(slug.value) : []
  return { course, units }
})

const course = computed(() => data.value?.course ?? null)
const units = computed(() => data.value?.units ?? [])

const allLessons = computed(() =>
  units.value.filter(unit => unit.disponible).flatMap(unit => unit.lessons)
)

const completedTotal = computed(() =>
  units.value.reduce((total, unit) => total + countApprovedLessons(unit), 0)
)

const overallPct = computed(() =>
  allLessons.value.length === 0
    ? 0
    : Math.round((completedTotal.value / allLessons.value.length) * 100)
)

const overallText = computed(
  () =>
    `${completedTotal.value}/${allLessons.value.length} lecciones aprobadas (${overallPct.value}%)`
)

function openUnit(unit) {
  router.push({
    name: 'unidad',
    params: {
      slug: slug.value,
      unitId: unit.id
    }
  })
}
</script>

<style lang="scss" scoped>
.dl-back {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: #6b6b6b;
  font-weight: 800;
  text-transform: uppercase;
  font-size: 13px;
  letter-spacing: 0.4px;
  text-decoration: none;
  margin-bottom: 22px;

  &:hover {
    color: $dl-green-dark;
  }
}

.dl-course-hero {
  display: flex;
  align-items: center;
  gap: 22px;
  background: #fffef6;
  border: 2px solid $dl-gray;
  border-left: 10px solid var(--course-color);
  border-radius: 18px;
  padding: 26px;

  &__icon {
    flex: 0 0 auto;
    width: 92px;
    height: 92px;
    border-radius: 18px;
    background: var(--course-color);
    display: flex;
    align-items: center;
    justify-content: center;
    color: #ffffff;
  }

  &__tags {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
    margin-bottom: 4px;
  }

  &__accent {
    font-size: 13px;
    font-weight: 800;
    text-transform: uppercase;
    color: #8a8a8a;
  }

  &__title {
    font-size: clamp(24px, 3.5vw, 34px);
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 4px 0 8px;
  }

  &__desc {
    font-size: 15px;
    line-height: 1.5;
    color: $dl-ink;
    margin: 0 0 16px;
    max-width: 640px;
  }

  &__progress {
    max-width: 420px;
  }

  &__progress-bar {
    height: 12px;
    background: $dl-gray;
    border-radius: 999px;
    overflow: hidden;
  }

  &__progress-fill {
    height: 100%;
    background: $dl-green;
    border-radius: 999px;
    transition: width 0.3s ease;
  }

  &__progress-text {
    display: block;
    margin-top: 6px;
    font-size: 13px;
    font-weight: 700;
    color: #6b6b6b;
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
  margin-top: 18px;
  background: #fff8e6;
  color: #6b5b00;
}

.dl-notfound-banner {
  margin-top: 10px;
  background: #ffe9e9;
  color: #c00015;
}

@media (max-width: 600px) {
  .dl-course-hero {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
