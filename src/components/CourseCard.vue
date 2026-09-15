<template>
  <div
    class="dl-course-card"
    :class="{ 'dl-course-card--locked': !available }"
    :style="{ '--course-color': course.color }"
    role="button"
    :tabindex="available ? 0 : -1"
    :aria-disabled="!available"
    @click="handleClick"
    @keydown.enter="handleClick"
  >
    <div class="dl-course-card__visual">
      <q-icon :name="course.icon" size="42px" :color="iconColor" />
      <q-badge
        v-if="!available"
        rounded
        class="dl-course-card__soon"
        color="grey-6"
        label="Próximamente"
      />
    </div>

    <div class="dl-course-card__body">
      <div class="dl-course-card__tags">
        <span class="dl-badge dl-badge--available" v-if="available">
          <q-icon name="check_circle" />
          Disponible
        </span>
        <span class="dl-badge dl-badge--orange" v-else>
          <q-icon name="schedule" />
          Próximamente
        </span>
        <span class="dl-course-card__accent">{{ course.level }}</span>
      </div>

      <h3 class="dl-course-card__title">{{ course.title }}</h3>
      <p class="dl-course-card__desc">{{ course.shortDescription }}</p>

      <div class="dl-course-card__meta">
        <span class="dl-course-card__meta-item">
          <q-icon name="view_module" size="16px" />
          {{ course.unitsCount }} unidades
        </span>
      </div>
    </div>

    <span
      class="dl-course-card__arrow"
      :class="{ 'dl-course-card__arrow--disabled': !available }"
    >
      <q-icon :name="available ? 'chevron_right' : 'lock'" size="26px" />
    </span>
  </div>
</template>

<script setup>
import { computed } from 'vue'

// El componente recibe el curso desde el padre y emite "select" cuando el
// usuario hace clic en un curso disponible.
const props = defineProps({
  course: {
    type: Object,
    required: true
  }
})

const emit = defineEmits(['select'])

const available = computed(() => props.course.status === 'disponible')

const iconColor = computed(() => {
  if (props.course.color === '#f7df1e') return 'dark'
  return 'white'
})

function handleClick() {
  if (available.value) {
    emit('select', props.course)
  }
}
</script>

<style lang="scss" scoped>
.dl-course-card {
  display: flex;
  align-items: flex-start;
  gap: 18px;
  background: #ffffff;
  border: 2px solid $dl-gray;
  border-radius: 18px;
  padding: 20px;
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease,
    border-color 0.15s ease;

  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 10px 24px rgba(0, 0, 0, 0.08);
    border-color: var(--course-color);
  }

  &--locked {
    cursor: not-allowed;
    opacity: 0.75;

    &:hover {
      transform: none;
      box-shadow: none;
      border-color: $dl-gray;
    }
  }

  &__visual {
    flex: 0 0 auto;
    width: 78px;
    height: 78px;
    border-radius: 16px;
    background: var(--course-color);
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
  }

  &__soon {
    position: absolute;
    bottom: -10px;
    font-size: 10px;
    font-weight: 800;
    letter-spacing: 0.3px;
  }

  &__body {
    flex: 1 1 0;
    min-width: 0;
  }

  &__tags {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
    margin-bottom: 8px;
  }

  &__accent {
    font-size: 13px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: #8a8a8a;
  }

  &__title {
    font-size: 20px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0 0 6px;
  }

  &__desc {
    font-size: 14px;
    line-height: 1.5;
    color: $dl-ink;
    margin: 0 0 12px;
  }

  &__meta {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  &__meta-item {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    font-weight: 700;
    color: #6b6b6b;
  }

  &__arrow {
    flex: 0 0 auto;
    width: 46px;
    height: 46px;
    border-radius: 50%;
    background: #e9f7e2;
    color: $dl-green-dark;
    display: flex;
    align-items: center;
    justify-content: center;
    align-self: center;

    &--disabled {
      background: #efefef;
      color: #9a9a9a;
    }
  }
}
</style>
