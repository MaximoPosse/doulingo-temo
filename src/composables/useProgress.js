// Progreso del estudiante. Persiste en localStorage para que el estado de
// lecciones y unidades sobreviva al recargar la página.
//
// Reglas:
//   - Una lección queda "completada" cuando se aprueba.
//   - Una unidad queda "completada" al aprobar su última lección.
//   - Una lección/unidad está "desbloqueada" si es la primera o si el
//     elemento anterior está completado.

import { ref, watch } from 'vue'

const STORAGE_KEY = 'doulingo-progress'

function load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw)
      return {
        completedLessons: Array.isArray(parsed.completedLessons)
          ? parsed.completedLessons
          : [],
        completedUnits: Array.isArray(parsed.completedUnits)
          ? parsed.completedUnits
          : []
      }
    }
  } catch (err) {
    console.warn('No se pudo leer el progreso guardado', err)
  }
  return { completedLessons: [], completedUnits: [] }
}

const progress = ref(load())

watch(
  progress,
  value => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(value))
    } catch (err) {
      console.warn('No se pudo guardar el progreso', err)
    }
  },
  { deep: true }
)

function isLessonCompleted(lessonId) {
  return progress.value.completedLessons.includes(lessonId)
}

function isUnitCompleted(unitId) {
  return progress.value.completedUnits.includes(unitId)
}

function isLessonUnlocked(lesson, lessonIndex, lessons) {
  if (lessonIndex === 0) return true
  return isLessonCompleted(lessons[lessonIndex - 1].id)
}

function isUnitUnlocked(unit, unitIndex, units) {
  if (unitIndex === 0) return true
  return isUnitCompleted(units[unitIndex - 1].id)
}

function unitStatus(unit, unitIndex, units) {
  if (isUnitCompleted(unit.id)) return 'completada'
  if (isUnitUnlocked(unit, unitIndex, units)) return 'disponible'
  return 'bloqueada'
}

// Marca una lección como aprobada. Si es la última de su unidad, completa la unidad.
function completeLesson(lessonId, unitId, lessonIndex, lessons) {
  if (!isLessonCompleted(lessonId)) {
    progress.value.completedLessons.push(lessonId)
  }
  if (lessonIndex === lessons.length - 1 && !isUnitCompleted(unitId)) {
    progress.value.completedUnits.push(unitId)
  }
}

function resetProgress() {
  progress.value = { completedLessons: [], completedUnits: [] }
}

export function useProgress() {
  return {
    progress,
    isLessonCompleted,
    isLessonUnlocked,
    isUnitCompleted,
    isUnitUnlocked,
    unitStatus,
    completeLesson,
    resetProgress
  }
}
