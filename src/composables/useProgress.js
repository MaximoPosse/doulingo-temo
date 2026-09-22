// Progreso del participante (avance individual, no contenido).
//
// Conceptos:
//   - Completada: se terminó el intento de una lección (se llegó a la pantalla
//     de resultados). No equivale a aprobarla.
//   - Aprobada: en el intento se obtuvo al menos el umbral de aciertos. Solo
//     las lecciones aprobadas habilitan la siguiente.
//   - Reprobada: lección completada (intentada) pero por debajo del umbral.
//
// Progreso persistido en localStorage de forma provisional. En una etapa
// posterior se conservará en la base de datos compartida junto con la
// identificación de usuarios.

import { ref, watch } from 'vue'

const STORAGE_KEY = 'doulingo-progress'
const APPROBATION_THRESHOLD = 0.6

function passes(correct, total) {
  if (total === 0) return false
  return correct >= Math.ceil(total * APPROBATION_THRESHOLD)
}

function load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw)
      return {
        attemptedLessons: Array.isArray(parsed.attemptedLessons)
          ? parsed.attemptedLessons
          : [],
        approvedLessons: Array.isArray(parsed.approvedLessons)
          ? parsed.approvedLessons
          : []
      }
    }
  } catch (err) {
    console.warn('No se pudo leer el progreso guardado', err)
  }
  return { attemptedLessons: [], approvedLessons: [] }
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

// ---------- Lecciones ----------

function isLessonApproved(lessonId) {
  return progress.value.approvedLessons.includes(lessonId)
}

function isLessonAttempted(lessonId) {
  return progress.value.attemptedLessons.includes(lessonId)
}

// La primera lección de una unidad está desbloqueada; el resto se habilita
// cuando la anterior fue APROBADA.
function isLessonUnlocked(lessonIndex, lessons) {
  if (lessonIndex === 0) return true
  return isLessonApproved(lessons[lessonIndex - 1]?.id)
}

// Estado de una lección: pendiente | bloqueada | disponible | aprobada | reprobada
function lessonStatus(unit, lesson, lessonIndex, lessons) {
  if (!unit?.published) return 'pendiente'
  if (!isLessonUnlocked(lessonIndex, lessons)) return 'bloqueada'
  if (isLessonApproved(lesson.id)) return 'aprobada'
  if (isLessonAttempted(lesson.id)) return 'reprobada'
  return 'disponible'
}

// Registra un intento. La lección queda "completada" (intentada) siempre y
// "aprobada" si alcanza el umbral.
function completeAttempt(lessonId, { correct, total }) {
  if (!isLessonAttempted(lessonId)) {
    progress.value.attemptedLessons.push(lessonId)
  }
  if (passes(correct, total) && !isLessonApproved(lessonId)) {
    progress.value.approvedLessons.push(lessonId)
  }
}

function countApprovedLessons(unit) {
  return unit.lessons.filter(lesson => isLessonApproved(lesson.id)).length
}

// ---------- Unidades ----------

// Una unidad publicada está completada cuando TODAS sus lecciones están aprobadas.
function isUnitCompleted(unit) {
  return (
    unit?.published === true &&
    unit.lessons.length > 0 &&
    unit.lessons.every(lesson => isLessonApproved(lesson.id))
  )
}

function isUnitUnlocked(unit, unitIndex, units) {
  if (unitIndex === 0) return true
  return isUnitCompleted(units[unitIndex - 1])
}

// Estado de una unidad: pendiente | bloqueada | disponible | completada
function unitStatus(unit, unitIndex, units) {
  if (!unit.published) return 'pendiente'
  if (!isUnitUnlocked(unit, unitIndex, units)) return 'bloqueada'
  if (isUnitCompleted(unit)) return 'completada'
  return 'disponible'
}

function resetProgress() {
  progress.value = { attemptedLessons: [], approvedLessons: [] }
}

export function useProgress() {
  return {
    progress,
    passes,
    isLessonApproved,
    isLessonAttempted,
    isLessonUnlocked,
    lessonStatus,
    countApprovedLessons,
    isUnitCompleted,
    isUnitUnlocked,
    unitStatus,
    completeAttempt,
    resetProgress
  }
}
