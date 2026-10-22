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
        path: 'cursos/:slug/unidad/:unitId',
        name: 'unidad',
        component: () => import('@/pages/CourseUnitPage.vue')
      },
      {
        path: 'cursos/:slug/unidad/:unitId/leccion/:lessonId',
        name: 'leccion',
        component: () => import('@/pages/LessonPage.vue')
      },
      {
        path: 'acceso',
        name: 'acceso',
        component: () => import('@/pages/AuthPage.vue')
      },
      {
        path: 'perfil',
        name: 'perfil',
        // Ruta protegida: exige una sesión (invitado o cuenta permanente).
        meta: { requiresAuth: true },
        component: () => import('@/pages/ProfilePage.vue')
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
