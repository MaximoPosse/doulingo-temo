import { defineRouter } from '#q-app'
import {
  createMemoryHistory,
  createRouter,
  createWebHashHistory,
  createWebHistory
} from 'vue-router'

import routes from './routes.js'
import { initAuth, useAuth } from '@/composables/useAuth'
import { isNativeApp } from '@/lib/deepLink'

/*
 * If not building with SSR mode, you can
 * directly export the Router instantiation;
 *
 * The function below can be async too; either use
 * async/await or return a Promise which resolves
 * with the Router instance.
 */

export default defineRouter((/* { store, ssrContext } */) => {
  const createHistory = import.meta.env.QUASAR_SERVER
    ? createMemoryHistory
    : import.meta.env.QUASAR_VUE_ROUTER_MODE === 'history'
      ? createWebHistory
      : createWebHashHistory

  const Router = createRouter({
    scrollBehavior: () => ({ left: 0, top: 0 }),
    routes,

    // Leave this as is and make changes in quasar.conf.js instead!
    // quasar.conf.js -> build -> vueRouterMode
    // quasar.conf.js -> build -> publicPath
    history: createHistory(import.meta.env.QUASAR_VUE_ROUTER_BASE)
  })

  // Rutas protegidas: requieren una sesión activa (invitado o cuenta).
  // Antes de decidir se espera a que la sesión se restaure, para no
  // expulsar a un participante que ya tenía su sesión guardada.
  Router.beforeEach(async to => {
    // En el APK todo el recorrido exige sesión: la persona se registra con
    // su correo y su usuario antes de empezar, así sus datos y su puntaje
    // quedan en el ranking.
    const exigeSesion =
      to.meta?.requiresAuth ||
      (isNativeApp() && to.name !== 'acceso' && to.name !== 'ranking-publico')
    if (!exigeSesion) return true
    await initAuth()
    const { session, recoveryMode } = useAuth()
    if (session.value || recoveryMode.value) return true
    return { name: 'acceso', query: { next: to.fullPath } }
  })

  return Router
})
