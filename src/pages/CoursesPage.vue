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

      <div class="dl-courses__grid">
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
import { useRouter } from 'vue-router'
import { getCourses } from '@/data/courseRepository'
import CourseCard from '@/components/CourseCard.vue'
import usagiImg from '@/assets/usagi.webp'

const router = useRouter()

const courses = getCourses()

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
</style>
