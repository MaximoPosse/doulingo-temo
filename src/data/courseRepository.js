// Repositorio de contenido educativo: curso, unidades, lecciones, preguntas,
// opciones y comprobación de respuestas.
//
// Fuente de verdad: base de datos relacional Supabase (ver supabase/).
// Toda consulta pasa por Row Level Security: se leen únicamente contenidos
// publicados. Las soluciones NO se descargan nunca: se validan en el servidor
// mediante la función pública check_answer() (RPC).
//
// Los modelos devueltos al UI mantienen el mismo contrato que la etapa
// anterior (ids, prompt, options, lessons, actividades, etc.).

import { getSupabaseClient } from '@/lib/supabase'

function client() {
  return getSupabaseClient()
}

function unwrap(result) {
  if (result.error) {
    throw new Error(
      `No se pudieron cargar los datos. ${result.error.message ?? 'Error de conexión.'}`
    )
  }
  return result.data
}

function mapCourse(row) {
  return {
    id: row.id,
    slug: row.slug,
    title: row.titulo,
    description: row.descripcion,
    level: row.nivel,
    status: row.estado,
    color: row.color,
    icon: row.icono,
    unitsCount: Array.isArray(row.unidades) ? row.unidades.length : 0
  }
}

function mapUnit(row, lessons) {
  return {
    id: row.id,
    order: row.orden,
    title: row.titulo,
    description: row.descripcion,
    icon: row.icono,
    disponible: row.disponible,
    lessons
  }
}

function mapLesson(row) {
  return {
    id: row.id,
    order: row.orden,
    title: row.titulo,
    explanation: row.explicacion,
    codeExample: row.ejemplo_codigo,
    activityCount: Array.isArray(row.preguntas) ? row.preguntas.length : 0
  }
}

// ---------- Cursos ----------

export async function getCourses() {
  const rows = unwrap(
    await client()
      .from('cursos')
      .select(
        'id, slug, titulo, descripcion, nivel, estado, color, icono, orden, unidades(id)'
      )
      .order('orden', { ascending: true })
  )
  return (rows ?? []).filter(row => row.estado === 'disponible').map(mapCourse)
}

export async function getCourseBySlug(slug) {
  const rows = unwrap(
    await client()
      .from('cursos')
      .select(
        'id, slug, titulo, descripcion, nivel, estado, color, icono, orden, unidades(id)'
      )
      .eq('slug', slug)
  )
  const row = (rows ?? []).find(item => item.estado === 'disponible') ?? null
  return row ? mapCourse(row) : null
}

async function resolveCourseId(slug) {
  const rows = unwrap(
    await client()
      .from('cursos')
      .select('id')
      .eq('slug', slug)
      .eq('estado', 'disponible')
  )
  return rows?.[0]?.id ?? null
}

// ---------- Unidades (con sus lecciones) ----------

export async function getUnits(courseSlug) {
  const courseId = await resolveCourseId(courseSlug)
  if (!courseId) return []

  const [unitRows, lessonRows] = await Promise.all([
    unwrap(
      client()
        .from('unidades')
        .select('id, curso_id, orden, titulo, descripcion, icono, disponible')
        .eq('curso_id', courseId)
        .order('orden', { ascending: true })
    ),
    unwrap(
      client()
        .from('lecciones')
        .select(
          'id, unidad_id, orden, titulo, explicacion, ejemplo_codigo, preguntas(id)'
        )
        .order('unidad_id', { ascending: true })
        .order('orden', { ascending: true })
    )
  ])

  const byUnit = new Map()
  for (const unit of unitRows ?? []) {
    byUnit.set(unit.id, mapUnit(unit, []))
  }
  for (const lesson of lessonRows ?? []) {
    byUnit.get(lesson.unidad_id)?.lessons.push(mapLesson(lesson))
  }
  return [...byUnit.values()]
}

export async function getUnit(courseSlug, unitId) {
  const units = await getUnits(courseSlug)
  return units.find(unit => unit.id === unitId) ?? null
}

// ---------- Lecciones ----------

export async function getLessons(courseSlug, unitId) {
  const unit = await getUnit(courseSlug, unitId)
  return unit ? unit.lessons : []
}

export async function getLesson(courseSlug, unitId, lessonId) {
  const lessons = await getLessons(courseSlug, unitId)
  return lessons.find(lesson => lesson.id === lessonId) ?? null
}

// ---------- Actividades (preguntas + opciones) ----------

export async function getActivities(courseSlug, unitId, lessonId) {
  const lesson = await getLesson(courseSlug, unitId, lessonId)
  if (!lesson) return []

  const questionRows = unwrap(
    await client()
      .from('preguntas')
      .select('id, leccion_id, orden, enunciado, codigo')
      .eq('leccion_id', lessonId)
      .order('orden', { ascending: true })
  )

  const questionIds = (questionRows ?? []).map(question => question.id)
  const optionRows =
    questionIds.length > 0
      ? unwrap(
          await client()
            .from('opciones')
            .select('id, pregunta_id, orden, texto')
            .in('pregunta_id', questionIds)
            .order('pregunta_id', { ascending: true })
            .order('orden', { ascending: true })
        )
      : []

  const optionsByQuestion = new Map()
  for (const option of optionRows ?? []) {
    if (!optionsByQuestion.has(option.pregunta_id)) {
      optionsByQuestion.set(option.pregunta_id, [])
    }
    optionsByQuestion.get(option.pregunta_id).push({
      id: option.id,
      text: option.texto
    })
  }

  return (questionRows ?? []).map(question => ({
    id: question.id,
    lessonId: question.leccion_id,
    type: 'choice',
    prompt: question.enunciado,
    code: question.codigo ?? undefined,
    options: optionsByQuestion.get(question.id) ?? []
  }))
}

// ---------- Comprobación de respuestas (RPC en el servidor) ----------

// Llama a la función check_answer() de Supabase. El servidor valida que la
// pregunta exista y esté publicada, que la opción pertenezca a la pregunta y
// recién entonces compara contra la solución. Resuelve con
// { correcto, explicacion, opcion_correcta_id } o lanza un error.
export async function checkAnswer(questionId, optionId) {
  const rows = unwrap(
    await client().rpc('check_answer', {
      p_pregunta: questionId,
      p_opcion: optionId
    })
  )
  return rows?.[0] ?? null
}
