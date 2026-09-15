const routes = [
  {
    path: '/',
    component: () => import('@/layouts/MainLayout.vue'),
    children: [
      {
        path: '',
        name: 'inicio',
        component: () => import('@/pages/IndexPage.vue')
      },
      {
        path: 'cursos',
        name: 'cursos',
        component: () => import('@/pages/CoursesPage.vue')
      },
      {
        path: 'cursos/:slug',
        name: 'curso',
        component: () => import('@/pages/CourseDetailPage.vue')
      },
      {
        path: 'cursos/:slug/unidad/:unitId/leccion/:lessonId',
        name: 'leccion',
        component: () => import('@/pages/LessonPage.vue')
      },
      {
        path: '/:catchAll(.*)*',
        name: 'no-encontrada',
        component: () => import('@/pages/ErrorNotFound.vue')
      }
    ]
  }
]

export default routes
