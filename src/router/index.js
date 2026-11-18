import { defineRouter } from '#q-app'
import {
  createMemoryHistory,
  createRouter,
  createWebHashHistory,
  createWebHistory
} from 'vue-router'

import routes from './routes.js'
import { initAuth, useAuth } from '@/composables/useAuth'
import { alerta } from '@/lib/alertas'

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

  // Todo exige una sesión (invitado o cuenta) salvo el inicio, la pantalla de
  // acceso, el ranking público (se proyecta en la expo) y la página de error.
  // Antes de decidir se espera a que la sesión se restaure, para no expulsar
  // a un participante que ya tenía su sesión guardada.
  const PUBLICAS = ['inicio', 'acceso', 'ranking-publico', 'no-encontrada']
  Router.beforeEach(async to => {
    if (PUBLICAS.includes(to.name)) return true
    await initAuth()
    const { session, recoveryMode } = useAuth()
    if (session.value || recoveryMode.value) return true
    alerta('aviso', 'Para continuar entrá como invitado o creá una cuenta.')
    return { name: 'acceso', query: { next: to.fullPath } }
  })

  return Router
})
