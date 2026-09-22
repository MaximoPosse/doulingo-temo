<template>
  <q-page class="dl-page">
    <div class="dl-page__inner">
      <router-link :to="{ name: 'curso', params: { slug } }" class="dl-back">
        <q-icon name="arrow_back" size="18px" />
        Volver al curso
      </router-link>

      <template v-if="unit">
        <div class="dl-unit-head" :style="{ '--course-color': course.color }">
          <span class="dl-unit-head__icon">
            <q-icon :name="unit.icon" size="40px" />
          </span>

          <div class="dl-unit-head__text">
            <div class="dl-unit-head__tags">
              <span class="dl-badge" :class="unitBadgeClass">
                <q-icon :name="unitBadgeIcon" />
                {{ unitBadgeLabel }}
              </span>
            </div>
            <h1 class="dl-unit-head__title">
              Unidad {{ unit.order }} · {{ unit.title }}
            </h1>
            <p class="dl-unit-head__desc">{{ unit.description }}</p>

            <div class="dl-unit-head__progress">
              <div class="dl-unit-head__bar">
                <div
                  class="dl-unit-head__fill"
                  :style="{ width: `${progressPct}%` }"
                />
              </div>
              <span class="dl-unit-head__text-progress">
                {{ approvedCount }}/{{ lessons.length }} lecciones aprobadas
              </span>
            </div>
          </div>
        </div>

        <h2 class="dl-section-title q-mt-lg">Lecciones de la unidad</h2>
        <p class="dl-page__lead">
          Debes aprobar una lección para habilitar la siguiente. Repasa la
          explicación y los ejemplos antes de comenzar las actividades.
        </p>

        <div class="dl-lessons">
          <template v-if="lessons.length > 0">
            <LessonCard
              v-for="(lesson, index) in lessons"
              :key="lesson.id"
              :unit="unit"
              :lesson="lesson"
              :lesson-index="index"
              :lessons="lessons"
              @select="openLesson"
            />
          </template>
          <q-banner v-else rounded class="dl-pending-banner">
            <q-icon name="construction" size="22px" color="orange" />
            Esta unidad todavía está en preparación. Completa la unidad anterior
            y vuelve pronto.
          </q-banner>
        </div>
      </template>

      <q-banner v-else rounded class="dl-notfound-banner">
        <q-icon name="error_outline" size="22px" color="negative" />
        No encontramos esta unidad. Es posible que el identificador
        <strong>{{ unitParam }}</strong> no exista.
      </q-banner>
    </div>
  </q-page>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  getCourseBySlug,
  getUnits,
  getUnit,
  getLessons
} from '@/data/courseRepository'
import { useProgress } from '@/composables/useProgress'
import LessonCard from '@/components/LessonCard.vue'

const route = useRoute()
const router = useRouter()

const slug = computed(() => route.params.slug)
const unitParam = computed(() => route.params.unitId)

const { unitStatus, countApprovedLessons } = useProgress()

const course = computed(
  () => getCourseBySlug(slug.value) ?? { color: '#58cc02' }
)
const units = computed(() => getUnits(slug.value))
const unit = computed(() => getUnit(slug.value, unitParam.value))
const lessons = computed(() => getLessons(slug.value, unitParam.value))

const unitIndex = computed(() =>
  units.value.findIndex(u => u.id === unitParam.value)
)

const status = computed(() =>
  unit.value
    ? unitStatus(unit.value, unitIndex.value, units.value)
    : 'pendiente'
)

const approvedCount = computed(() =>
  unit.value ? countApprovedLessons(unit.value) : 0
)

const progressPct = computed(() =>
  lessons.value.length === 0
    ? 0
    : Math.round((approvedCount.value / lessons.value.length) * 100)
)

const badgeMap = {
  completada: {
    label: 'Completada',
    icon: 'check_circle',
    class: 'dl-badge--available'
  },
  disponible: {
    label: 'En curso',
    icon: 'play_circle',
    class: 'dl-badge--completed'
  },
  bloqueada: { label: 'Bloqueada', icon: 'lock', class: 'dl-badge--locked' },
  pendiente: { label: 'Pendiente', icon: 'schedule', class: 'dl-badge--orange' }
}

const unitBadgeLabel = computed(() => badgeMap[status.value].label)
const unitBadgeIcon = computed(() => badgeMap[status.value].icon)
const unitBadgeClass = computed(() => badgeMap[status.value].class)

function openLesson(lesson) {
  router.push({
    name: 'leccion',
    params: { slug: slug.value, unitId: unit.value.id, lessonId: lesson.id }
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

.dl-unit-head {
  display: flex;
  gap: 22px;
  background: #fffef6;
  border: 2px solid $dl-gray;
  border-left: 10px solid var(--course-color);
  border-radius: 18px;
  padding: 26px;
  align-items: center;

  &__icon {
    flex: 0 0 auto;
    width: 84px;
    height: 84px;
    border-radius: 18px;
    background: $dl-blue;
    color: #ffffff;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  &__text {
    flex: 1 1 0;
    min-width: 0;
  }

  &__title {
    font-size: clamp(22px, 3vw, 30px);
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 6px 0 8px;
  }

  &__desc {
    font-size: 15px;
    line-height: 1.5;
    color: $dl-ink;
    margin: 0 0 14px;
    max-width: 620px;
  }

  &__progress {
    max-width: 420px;
  }

  &__bar {
    height: 12px;
    background: $dl-gray;
    border-radius: 999px;
    overflow: hidden;
  }

  &__fill {
    height: 100%;
    background: $dl-green;
    border-radius: 999px;
    transition: width 0.3s ease;
  }

  &__text-progress {
    display: block;
    margin-top: 6px;
    font-size: 13px;
    font-weight: 700;
    color: #6b6b6b;
  }
}

.dl-lessons {
  display: flex;
  flex-direction: column;
  gap: 14px;
  max-width: 720px;
}

.dl-pending-banner {
  background: #fff8e6;
  color: #6b5b00;
}

.dl-notfound-banner {
  background: #ffe9e9;
  color: #c00015;
}

@media (max-width: 600px) {
  .dl-unit-head {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
