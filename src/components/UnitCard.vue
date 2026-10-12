<template>
  <div class="dl-unit">
    <div class="dl-unit__rail">
      <span
        class="dl-unit__circle"
        :class="[
          `dl-unit__circle--${status}`,
          {
            'dl-unit__circle--current':
              status === 'disponible' && isFirstUnfinished
          }
        ]"
      >
        <q-icon v-if="status === 'completada'" name="check" size="24px" />
        <q-icon
          v-else-if="status === 'bloqueada' || status === 'pendiente'"
          name="lock"
          size="20px"
        />
        <q-icon v-else :name="unit.icon" size="22px" />
      </span>
      <span v-if="!isLast" class="dl-unit__line" />
    </div>

    <div
      class="dl-unit__card"
      :class="{ 'dl-unit__card--disabled': !clickable }"
      role="button"
      :tabindex="clickable ? 0 : -1"
      :aria-disabled="!clickable"
      @click="handleClick"
      @keydown.enter="handleClick"
    >
      <div class="dl-unit__card-head">
        <div class="dl-unit__titles">
          <span class="dl-unit__order">Unidad {{ unit.order }}</span>
          <h3 class="dl-unit__title">{{ unit.title }}</h3>
        </div>
        <span class="dl-badge" :class="badgeClass">
          <q-icon :name="badgeInfo.icon" />
          {{ badgeInfo.label }}
        </span>
      </div>

      <p class="dl-unit__desc">{{ unit.description }}</p>

      <div class="dl-unit__foot">
        <div class="dl-unit__progress">
          <div class="dl-unit__progress-bar">
            <div
              class="dl-unit__progress-fill"
              :class="{
                'dl-unit__progress-fill--done': status === 'completada'
              }"
              :style="{ width: `${progressPct}%` }"
            />
          </div>
          <span class="dl-unit__progress-text">{{ progressText }}</span>
        </div>
        <span
          class="dl-unit__go"
          :class="{ 'dl-unit__go--disabled': !clickable }"
        >
          <q-icon :name="clickable ? 'chevron_right' : 'lock'" size="22px" />
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
  unitIndex: { type: Number, required: true },
  units: { type: Array, required: true }
})

const emit = defineEmits(['select'])

const { unitStatus, countApprovedLessons } = useProgress()

const status = computed(() =>
  unitStatus(props.unit, props.unitIndex, props.units)
)

const isLast = computed(() => props.unitIndex === props.units.length - 1)

const clickable = computed(
  () => status.value === 'disponible' || status.value === 'completada'
)

const approvedCount = computed(() => countApprovedLessons(props.unit))
const totalLessons = computed(() => props.unit.lessons.length)

const progressPct = computed(() =>
  totalLessons.value === 0
    ? 0
    : Math.round((approvedCount.value / totalLessons.value) * 100)
)

const progressText = computed(() => {
  if (status.value === 'pendiente') return 'En preparación'
  if (totalLessons.value === 0) return 'Sin lecciones aún'
  return `${approvedCount.value}/${totalLessons.value} lecciones aprobadas`
})

// El primer nodo no completado de las unidades publicadas es el "actual".
const isFirstUnfinished = computed(() => {
  const availableUnits = props.units.filter(unit => unit.disponible)
  const firstUncompleted = availableUnits.findIndex(
    unit => unitStatus(unit, props.unitIndex, props.units) !== 'completada'
  )
  return availableUnits[firstUncompleted]?.id === props.unit.id
})

const badgeMap = {
  completada: {
    label: 'Completada',
    icon: 'check_circle',
    class: 'dl-badge--available'
  },
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
    emit('select', props.unit)
  }
}
</script>

<style lang="scss" scoped>
.dl-unit {
  display: flex;
  gap: 18px;
  align-items: stretch;

  &__rail {
    flex: 0 0 66px;
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  &__circle {
    flex: 0 0 auto;
    width: 64px;
    height: 64px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #ffffff;

    &--disponible {
      background: $dl-blue;
      box-shadow: 0 4px 0 #1899d6;
    }

    &--completada {
      background: $dl-green;
      box-shadow: 0 4px 0 $dl-green-dark;
    }

    &--bloqueada,
    &--pendiente {
      background: $dl-gray;
      color: #9a9a9a;
      box-shadow: 0 4px 0 #cfcfcf;
    }

    &--current {
      animation: dl-pulse 1.6s ease-in-out infinite;
    }
  }

  &__line {
    flex: 1 1 0;
    width: 6px;
    min-height: 24px;
    background: $dl-gray;
    border-radius: 3px;
  }

  &__card {
    flex: 1 1 0;
    min-width: 0;
    background: #ffffff;
    border: 2px solid $dl-gray;
    border-radius: 16px;
    padding: 18px 20px;
    margin-bottom: 22px;
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
  }

  &__card-head {
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
    font-size: 19px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0;
  }

  &__desc {
    font-size: 14px;
    line-height: 1.5;
    color: $dl-ink;
    margin: 8px 0 14px;
  }

  &__foot {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  &__progress {
    flex: 1 1 0;
    min-width: 160px;
  }

  &__progress-bar {
    height: 12px;
    background: $dl-gray;
    border-radius: 999px;
    overflow: hidden;
  }

  &__progress-fill {
    height: 100%;
    background: $dl-blue;
    border-radius: 999px;
    transition: width 0.3s ease;

    &--done {
      background: $dl-green;
    }
  }

  &__progress-text {
    display: block;
    margin-top: 6px;
    font-size: 12px;
    font-weight: 700;
    color: #6b6b6b;
  }

  &__go {
    flex: 0 0 auto;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: #e9f7e2;
    color: $dl-green-dark;
    display: flex;
    align-items: center;
    justify-content: center;

    &--disabled {
      background: #efefef;
      color: #9a9a9a;
    }
  }
}

@keyframes dl-pulse {
  0%,
  100% {
    transform: scale(1);
  }

  50% {
    transform: scale(1.07);
  }
}
</style>
