// Módulo de acceso a datos (repositorio).
//
// Todas las pantallas obtienen cursos, unidades, lecciones y actividades a
// través de este módulo. En esta etapa los datos son archivos JavaScript de
// prueba; en una etapa posterior, las mismas funciones consultarán la base de
// datos compartida sin que las pantallas cambien.

import { courses as courseCatalog } from './courses.js'
import { javascriptCourse } from './javascriptCourse.js'

// Contenido educativo por curso. El curso "javascript" es el único que hoy
// posee unidades publicadas.
const coursesContent = {
  javascript: javascriptCourse
}

export function getCourses() {
  return courseCatalog.map(course => ({
    ...course,
    unitsCount: getUnits(course.slug).length
  }))
}

export function getCourseBySlug(slug) {
  const content = coursesContent[slug]
  if (content) {
    return { ...content, unitsCount: content.units.length }
  }
  return courseCatalog.find(course => course.slug === slug) ?? null
}

export function getUnits(courseSlug) {
  const content = coursesContent[courseSlug]
  return content ? content.units : []
}

export function getPublishedUnits(courseSlug) {
  return getUnits(courseSlug).filter(unit => unit.published)
}

export function getUnit(courseSlug, unitId) {
  return getUnits(courseSlug).find(unit => unit.id === unitId) ?? null
}

export function getLessons(courseSlug, unitId) {
  const unit = getUnit(courseSlug, unitId)
  return unit ? unit.lessons : []
}

export function getLesson(courseSlug, unitId, lessonId) {
  return (
    getLessons(courseSlug, unitId).find(lesson => lesson.id === lessonId) ??
    null
  )
}

export function getActivities(courseSlug, unitId, lessonId) {
  const lesson = getLesson(courseSlug, unitId, lessonId)
  return lesson ? lesson.activities : []
}
