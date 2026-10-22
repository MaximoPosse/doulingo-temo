// Progreso del participante (avance individual, no contenido).
//
// Conceptos:
//   - Completada: se terminó el intento de una lección (se llegó a la pantalla
//     de resultados). No equivale a aprobarla.
//   - Aprobada: en el intento se obtuvo al menos el umbral de aciertos. Solo
//     las lecciones aprobadas habilitan la siguiente.
//   - Reprobada: lección completada (intentada) pero por debajo del umbral.
//
// Dónde vive el progreso:
//   - En el dispositivo (localStorage) siempre, como copia local de trabajo.
//   - En la base de datos cuando hay sesión: `participant_progress` guarda el
//     avance por lección y lo escribe únicamente finalizar_intento() a partir
//     de los intentos y respuestas guardados en el servidor.
//   El identificador del participante es el id de Supabase Auth, así que el
//   historial se conserva al convertir la sesión de invitado en cuenta
//   permanente: es el mismo id. El detalle de cada intento vive en las tablas
//   `intentos` e `intentos_respuestas`.
//
// El contenido (lecciones/actividades, campos `disponible` de cada unidad)
// proviene del repositorio remoto (Supabase); aquí solo se guarda el avance.

import { ref, watch } from 'vue'

import { fetchProgress, clearServerProgress } from '@/data/authRepository'
import { clearAttempts } from '@/data/attemptRepository'

const STORAGE_KEY = 'doulingo-progress'
const SCOPED_PREFIX = 'doulingo-progress:'
const APPROBATION_THRESHOLD = 0.6

function passes(correct, total) {
  if (total === 0) return false
  return correct >= Math.ceil(total * APPROBATION_THRESHOLD)
}

function normalize(parsed) {
  return {
    attemptedLessons: Array.isArray(parsed?.attemptedLessons)
      ? parsed.attemptedLessons
      : [],
    approvedLessons: Array.isArray(parsed?.approvedLessons)
      ? parsed.approvedLessons
      : []
  }
}

function readJson(key) {
  try {
    const raw = localStorage.getItem(key)
    return raw ? normalize(JSON.parse(raw)) : null
  } catch (err) {
    console.warn('No se pudo leer el progreso guardado', err)
    return null
  }
}

function writeJson(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch (err) {
    console.warn('No se pudo guardar el progreso', err)
  }
}

function removeKey(key) {
  try {
    localStorage.removeItem(key)
  } catch (err) {
    console.warn('No se pudo borrar el progreso', err)
  }
}

function emptyProgress() {
  return { attemptedLessons: [], approvedLessons: [] }
}

// Identificador del participante al que pertenece el progreso en pantalla.
let currentUid = null

const progress = ref(readJson(STORAGE_KEY) ?? emptyProgress())

watch(
  progress,
  value => {
    if (
      !currentUid &&
      !value.attemptedLessons.length &&
      !value.approvedLessons.length
    ) {
      // Sin sesión y sin avance: no se guarda nada (contexto limpio).
      removeKey(STORAGE_KEY)
      return
    }
    const key = currentUid ? `${SCOPED_PREFIX}${currentUid}` : STORAGE_KEY
    writeJson(key, value)
  },
  { deep: true }
)

// ---------- Vínculo con la sesión ----------

// Asocia el progreso en pantalla con un participante:
//   - con sesión: usa (y crea) el espacio de ese identificador;
//   - sin sesión: muestra un progreso vacío (nadie más ve el de otro).
// El primer inicio de sesión adopta el progreso que venía del navegador
// (guardado antes de existir las cuentas), para no perder el avance.
export function attachToUser(uid) {
  currentUid = uid
  if (!uid) {
    progress.value = emptyProgress()
    return
  }
  const scopedKey = `${SCOPED_PREFIX}${uid}`
  const scoped = readJson(scopedKey)
  const legacy = readJson(STORAGE_KEY)
  if (scoped && legacy) {
    // El avance hecho sin sesión se une al ya guardado del participante.
    const merged = mergeProgress(scoped, legacy)
    writeJson(scopedKey, merged)
    removeKey(STORAGE_KEY)
    progress.value = merged
  } else if (scoped) {
    progress.value = scoped
  } else if (legacy) {
    writeJson(scopedKey, legacy)
    removeKey(STORAGE_KEY)
    progress.value = legacy
  } else {
    progress.value = emptyProgress()
  }
  mergeFromServer(uid)
}

// Une dos avances: lo aprobado está en ambas listas y lo intentado en alguna.
function mergeProgress(base, extra) {
  const merged = normalize(base)
  for (const id of normalize(extra).attemptedLessons) {
    if (!merged.attemptedLessons.includes(id)) merged.attemptedLessons.push(id)
  }
  for (const id of normalize(extra).approvedLessons) {
    if (!merged.approvedLessons.includes(id)) merged.approvedLessons.push(id)
  }
  return merged
}

// Une el progreso guardado en la base con el del dispositivo.
async function mergeFromServer(uid) {
  try {
    const rows = await fetchProgress(uid)
    if (!rows?.length) return
    const merged = normalize(progress.value)
    let changed = false
    for (const row of rows) {
      if (!merged.attemptedLessons.includes(row.leccion_id)) {
        merged.attemptedLessons.push(row.leccion_id)
        changed = true
      }
      if (
        row.estado === 'aprobada' &&
        !merged.approvedLessons.includes(row.leccion_id)
      ) {
        merged.approvedLessons.push(row.leccion_id)
        changed = true
      }
    }
    if (changed) progress.value = merged
  } catch (err) {
    // Sin conexión: se sigue con la copia local.
    console.warn('No se pudo sincronizar el progreso con la base', err)
  }
}

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
  if (!unit?.disponible) return 'pendiente'
  if (!isLessonUnlocked(lessonIndex, lessons)) return 'bloqueada'
  if (isLessonApproved(lesson.id)) return 'aprobada'
  if (isLessonAttempted(lesson.id)) return 'reprobada'
  return 'disponible'
}

// Registra en el dispositivo el resultado de un intento YA GUARDADO en el
// servidor. La fila de participant_progress la escribe finalizar_intento():
// acá solo se actualiza la copia local que usa la interfaz.
function completeAttempt(lessonId, { passed }) {
  if (!isLessonAttempted(lessonId)) {
    progress.value.attemptedLessons.push(lessonId)
  }
  const approved = passed === true
  if (approved && !isLessonApproved(lessonId)) {
    progress.value.approvedLessons.push(lessonId)
  }
  return approved
}

function countApprovedLessons(unit) {
  return unit.lessons.filter(lesson => isLessonApproved(lesson.id)).length
}

// ---------- Unidades ----------

// Una unidad publicada está completada cuando TODAS sus lecciones están aprobadas.
function isUnitCompleted(unit) {
  return (
    unit?.disponible === true &&
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
  if (!unit.disponible) return 'pendiente'
  if (!isUnitUnlocked(unit, unitIndex, units)) return 'bloqueada'
  if (isUnitCompleted(unit)) return 'completada'
  return 'disponible'
}

function resetProgress() {
  progress.value = emptyProgress()
}

// Borra el historial completo del participante: los intentos y el avance
// guardados en la base (solo sus propias filas, por RLS) y la copia local.
async function clearHistory() {
  const uid = currentUid
  resetProgress()
  if (!uid) return
  await clearAttempts()
  await clearServerProgress(uid)
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
    resetProgress,
    clearHistory,
    attachToUser
  }
}
