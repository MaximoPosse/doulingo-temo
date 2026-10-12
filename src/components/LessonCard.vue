<template>
  <div
    class="dl-lesson-card"
    :class="{ 'dl-lesson-card--disabled': !clickable }"
    role="button"
    :tabindex="clickable ? 0 : -1"
    :aria-disabled="!clickable"
    @click="handleClick"
    @keydown.enter="handleClick"
  >
    <span class="dl-lesson-card__num" :class="`dl-lesson-card__num--${status}`">
      <q-icon v-if="status === 'aprobada'" name="check" size="20px" />
      <q-icon
        v-else-if="status === 'bloqueada' || status === 'pendiente'"
        name="lock"
        size="18px"
      />
      <template v-else>{{ lessonIndex + 1 }}</template>
    </span>

    <div class="dl-lesson-card__body">
      <div class="dl-lesson-card__head">
        <div>
          <span class="dl-lesson-card__order"
            >Lección {{ lessonIndex + 1 }}</span
          >
          <h3 class="dl-lesson-card__title">{{ lesson.title }}</h3>
        </div>
        <span class="dl-badge" :class="badgeClass">
          <q-icon :name="badgeInfo.icon" />
          {{ badgeInfo.label }}
        </span>
      </div>

      <p class="dl-lesson-card__desc">
        {{ lesson.activityCount }} actividades ·
        {{
          lesson.activityCount >= 3
            ? 'aprueba con 2 de 3'
            : 'aprueba respondiendo bien la mayoría'
        }}
      </p>

      <div class="dl-lesson-card__action">
        <span
          class="dl-lesson-card__cta"
          :class="{ 'dl-lesson-card__cta--disabled': !clickable }"
        >
          <template v-if="status === 'aprobada'">Repasar</template>
          <template v-else-if="status === 'reprobada'">Reintentar</template>
          <template v-else-if="status === 'disponible'">Comenzar</template>
          <template v-else>Bloqueada</template>
          <q-icon :name="clickable ? 'chevron_right' : 'lock'" size="20px" />
        </span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useProgress } from '@/composables/useProgress'

const props = defineProps({
  unit: { type: Object, required: true },
  lesson: { type: Object, required: true },
  lessonIndex: { type: Number, required: true },
  lessons: { type: Array, required: true }
})

const emit = defineEmits(['select'])

const { lessonStatus } = useProgress()

const status = computed(() =>
  lessonStatus(props.unit, props.lesson, props.lessonIndex, props.lessons)
)

const clickable = computed(() =>
  ['aprobada', 'reprobada', 'disponible'].includes(status.value)
)

const badgeMap = {
  aprobada: {
    label: 'Aprobada',
    icon: 'check_circle',
    class: 'dl-badge--available'
  },
  reprobada: { label: 'Reintentar', icon: 'replay', class: 'dl-badge--locked' },
  disponible: {
    label: 'Disponible',
    icon: 'play_circle',
    class: 'dl-badge--completed'
  },
  bloqueada: { label: 'Bloqueada', icon: 'lock', class: 'dl-badge--locked' },
  pendiente: { label: 'Pendiente', icon: 'schedule', class: 'dl-badge--orange' }
}

const badgeInfo = computed(() => badgeMap[status.value])
const badgeClass = computed(() => badgeInfo.value.class)

function handleClick() {
  if (clickable.value) {
    emit('select', props.lesson)
  }
}
</script>

<style lang="scss" scoped>
.dl-lesson-card {
  display: flex;
  gap: 16px;
  align-items: flex-start;
  background: #ffffff;
  border: 2px solid $dl-gray;
  border-radius: 16px;
  padding: 18px 20px;
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease,
    border-color 0.15s ease;

  &:hover {
    transform: translateY(-3px);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.08);
    border-color: $dl-green;
  }

  &--disabled {
    cursor: not-allowed;
    background: #fafafa;

    &:hover {
      transform: none;
      box-shadow: none;
      border-color: $dl-gray;
    }
  }

  &__num {
    flex: 0 0 auto;
    width: 44px;
    height: 44px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
    color: #ffffff;

    &--disponible {
      background: $dl-blue;
      box-shadow: 0 3px 0 #1899d6;
    }

    &--aprobada {
      background: $dl-green;
      box-shadow: 0 3px 0 $dl-green-dark;
    }

    &--reprobada {
      background: $dl-orange;
      box-shadow: 0 3px 0 #e08600;
    }

    &--bloqueada,
    &--pendiente {
      background: $dl-gray;
      color: #9a9a9a;
      box-shadow: 0 3px 0 #cfcfcf;
    }
  }

  &__body {
    flex: 1 1 0;
    min-width: 0;
  }

  &__head {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    flex-wrap: wrap;
  }

  &__order {
    display: block;
    font-size: 12px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: #8a8a8a;
    margin-bottom: 2px;
  }

  &__title {
    font-size: 18px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0;
  }

  &__desc {
    font-size: 13px;
    color: $dl-ink;
    margin: 6px 0 10px;
  }

  &__action {
    text-align: right;
  }

  &__cta {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: $dl-green-dark;

    &--disabled {
      color: #9a9a9a;
    }
  }
}
</style>
