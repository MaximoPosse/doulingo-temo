<template>
  <q-page class="dl-page">
    <div class="dl-page__inner">
      <router-link to="/cursos" class="dl-back">
        <q-icon name="arrow_back" size="18px" />
        Volver a cursos
      </router-link>

      <!-- Curso en preparación -->
      <template v-if="!course.available">
        <div
          class="dl-course-hero dl-course-hero--soon"
          :style="{ '--course-color': course.color }"
        >
          <span class="dl-course-hero__icon">
            <q-icon :name="course.icon" size="44px" />
          </span>
          <div>
            <span class="dl-badge dl-badge--orange">
              <q-icon name="schedule" />
              Próximamente
            </span>
            <h1 class="dl-course-hero__title">{{ course.title }}</h1>
            <p class="dl-course-hero__desc">{{ course.description }}</p>
          </div>
        </div>
        <q-banner class="dl-soon-banner" rounded>
          <q-icon name="construction" size="22px" color="orange" />
          Este curso todavía está en preparación. Elige otro curso disponible o
          vuelve más tarde.
        </q-banner>
      </template>

      <!-- Curso disponible -->
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
import { getCourseBySlug } from '@/data/courses'
import { javascriptCourse } from '@/data/javascriptCourse'
import { useProgress } from '@/composables/useProgress'
import UnitCard from '@/components/UnitCard.vue'

const route = useRoute()
const router = useRouter()
const { isLessonCompleted } = useProgress()

const slug = computed(() => route.params.slug)

const meta = computed(() => getCourseBySlug(slug.value) ?? javascriptCourse)

// El curso "javascript" es el único con unidades cargadas por ahora; el resto
// se muestra como "próximamente".
const course = computed(() => ({
  ...meta.value,
  available: slug.value === 'javascript'
}))

const units = computed(() =>
  slug.value === 'javascript' ? javascriptCourse.units : []
)

const allLessons = computed(() => units.value.flatMap(unit => unit.lessons))

const completedTotal = computed(
  () => allLessons.value.filter(lesson => isLessonCompleted(lesson.id)).length
)

const overallPct = computed(() =>
  allLessons.value.length === 0
    ? 0
    : Math.round((completedTotal.value / allLessons.value.length) * 100)
)

const overallText = computed(
  () =>
    `${completedTotal.value}/${allLessons.value.length} lecciones completadas (${overallPct.value}%)`
)

function openUnit(unit) {
  const firstLesson = unit.lessons[0]
  router.push({
    name: 'leccion',
    params: {
      slug: slug.value,
      unitId: unit.id,
      lessonId: firstLesson.id
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

  &--soon {
    opacity: 0.9;
  }

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

.dl-soon-banner {
  margin-top: 22px;
  background: #fff8e6;
  color: #6b5b00;
}

@media (max-width: 600px) {
  .dl-course-hero {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
