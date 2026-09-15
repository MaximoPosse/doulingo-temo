// Catálogo de cursos disponibles en Doulingo.
// Cada curso tiene, como mínimo: nombre, descripción, estado y una
// representación visual (color + icono) que la tarjeta CourseCard utiliza.

export const courses = [
  {
    id: 'javascript',
    slug: 'javascript',
    title: 'JavaScript desde cero',
    shortDescription:
      'El lenguaje que da vida a la web: variables, condicionales, bucles y funciones.',
    description:
      'Curso introductorio pensado para personas sin experiencia previa. Avanza por cinco unidades con lecciones breves y actividades con retroalimentación inmediata.',
    level: 'Principiante',
    status: 'disponible',
    color: '#f7df1e',
    icon: 'code',
    unitsCount: 5
  },
  {
    id: 'python',
    slug: 'python',
    title: 'Python: primeros pasos',
    shortDescription:
      'Un lenguaje claro y poderoso para empezar a automatizar tareas y analizar datos.',
    description:
      'Curso en preparación. Aprenderás sintaxis básica, variables y estructuras de control con un lenguaje legible y amigable.',
    level: 'Principiante',
    status: 'proximamente',
    color: '#3776ab',
    icon: 'data_object',
    unitsCount: 5
  },
  {
    id: 'html-css',
    slug: 'html-css',
    title: 'HTML y CSS: construye la web',
    shortDescription:
      'La estructura y el estilo de toda página web, con una base visual inmediata.',
    description:
      'Curso en preparación. Aprenderás a crear la estructura de una página y a darle estilo con hojas de cascada.',
    level: 'Principiante',
    status: 'proximamente',
    color: '#e34f26',
    icon: 'palette',
    unitsCount: 4
  }
]

export function getCourseBySlug(slug) {
  return courses.find(course => course.slug === slug)
}
