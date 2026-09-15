<template>
  <q-page class="dl-landing">
    <!-- Hero -->
    <section class="dl-hero dl-hero--home">
      <div class="dl-hero__inner">
        <div class="dl-hero__text">
          <h1 class="dl-hero__title">
            La forma gratuita, divertida y efectiva de aprender a
            <span class="dl-underline">programar</span>.
          </h1>
          <p class="dl-hero__subtitle">
            Unidades y lecciones breves, actividades y retroalimentación
            inmediata. No necesitas conocimientos previos: solo empieza hoy.
          </p>

          <div class="dl-hero__cta">
            <q-btn
              no-caps
              unelevated
              size="lg"
              class="dl-btn-main dl-btn-main--big"
              label="EMPIEZA GRATIS"
              :to="{ name: 'cursos' }"
            />
            <q-btn
              no-caps
              outline
              size="lg"
              class="dl-btn-ghost dl-btn-ghost--card"
              label="VER CURSOS"
              :to="{ name: 'cursos' }"
            />
          </div>
        </div>

        <div class="dl-hero__mascot">
          <img :src="usagiImg" alt="Usagi saludando" />
          <span class="dl-hero__bubble">¡Vamos a aprender!</span>
        </div>
      </div>
    </section>

    <!-- Banda de garantías -->
    <section class="dl-promise">
      <div class="dl-promise__inner">
        <span class="dl-promise__item">
          <q-icon name="lock_open" size="22px" />
          Gratis para siempre
        </span>
        <span class="dl-promise__item">
          <q-icon name="eco" size="22px" />
          Cero conocimientos previos
        </span>
        <span class="dl-promise__item">
          <q-icon name="schedule" size="22px" />
          A tu ritmo, 5 minutos al día
        </span>
      </div>
    </section>

    <!-- Características -->
    <section class="dl-features">
      <div class="dl-features__inner">
        <h2 class="dl-section-title">¿Por qué Doulingo?</h2>

        <div class="dl-features__grid">
          <div class="dl-card">
            <span class="dl-card__icon dl-card__icon--green">
              <q-icon name="flash_on" />
            </span>
            <h3 class="dl-card__title">Lecciones breves</h3>
            <p class="dl-card__text">
              Actividades de 3 a 5 minutos que caben perfectamente en tu día.
            </p>
          </div>

          <div class="dl-card">
            <span class="dl-card__icon dl-card__icon--blue">
              <q-icon name="check_circle" />
            </span>
            <h3 class="dl-card__title">Retroalimentación inmediata</h3>
            <p class="dl-card__text">
              Sabes al instante si tu respuesta es correcta... y por qué.
            </p>
          </div>

          <div class="dl-card">
            <span class="dl-card__icon dl-card__icon--gold">
              <q-icon name="trending_up" />
            </span>
            <h3 class="dl-card__title">Progreso visible</h3>
            <p class="dl-card__text">
              Unidades, niveles y rachas que te muestran cuánto estás avanzando.
            </p>
          </div>

          <div class="dl-card">
            <span class="dl-card__icon dl-card__icon--purple">
              <q-icon name="emoji_events" />
            </span>
            <h3 class="dl-card__title">Gamificación</h3>
            <p class="dl-card__text">
              Puntos y logros que convierten estudiar en un juego.
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- Camino de aprendizaje -->
    <section class="dl-path">
      <div class="dl-path__inner">
        <h2 class="dl-section-title">Así funciona</h2>
        <p class="dl-path__lead">
          Avanza por unidades con un camino visual, paso a paso, de la mano de
          tu guía Usagi.
        </p>

        <div class="dl-path__demo">
          <div class="dl-demo">
            <div class="dl-demo__head">
              <img :src="usagiImg" alt="Usagi guía" class="dl-demo__mascot" />
            </div>
            <div class="dl-demo__line" />
            <div
              v-for="(node, index) in pathNodes"
              :key="node.label"
              class="dl-demo__node"
              :class="{
                'dl-demo__node--current': node.current,
                'dl-demo__node--locked': node.locked
              }"
            >
              <span class="dl-demo__circle">
                <q-icon :name="node.icon" size="22px" />
              </span>
              <span class="dl-demo__label">{{ node.label }}</span>
            </div>
          </div>

          <div class="dl-path__copy">
            <h3 class="dl-path__title">De cero a dominar un lenguaje</h3>
            <ul class="dl-path__list">
              <li>Empiezas con la unidad 1: fundamentos.</li>
              <li>Cada unidad se divide en lecciones cortas.</li>
              <li>Resuelves actividades y recibes ayuda al instante.</li>
              <li>Desbloqueas la siguiente unidad al completar la anterior.</li>
              <li>Tu progreso se guarda automáticamente.</li>
            </ul>
          </div>
        </div>
      </div>
    </section>

    <!-- Footer -->
    <footer class="dl-footer">
      <div class="dl-footer__inner">
        <div class="dl-brand">
          <img :src="usagiImg" alt="Usagi" class="dl-brand__mascot" />
          <span class="dl-brand__name">Doulingo</span>
        </div>
        <p class="dl-footer__note">
          Proyecto educativo de código abierto. Hecho con Vue JS y Quasar.
        </p>
      </div>
    </footer>
  </q-page>
</template>

<script setup>
import usagiImg from '@/assets/usagi.webp'

const pathNodes = [
  { label: 'Fundamentos', icon: 'code', current: false, locked: false },
  {
    label: 'Variables y datos',
    icon: 'data_object',
    current: false,
    locked: false
  },
  { label: 'Condicionales', icon: 'play_circle', current: true, locked: false },
  { label: 'Bucles', icon: 'lock', current: false, locked: true },
  { label: 'Funciones', icon: 'lock', current: false, locked: true }
]
</script>

<style lang="scss" scoped>
.dl-landing {
  background: #ffffff;
  font-family: 'Nunito', 'Quicksand', 'Segoe UI', sans-serif;
}

.dl-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: #ffffff;
  border-bottom: 2px solid $dl-gray;

  &__inner {
    max-width: 1100px;
    margin: 0 auto;
    padding: 10px 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  &__actions {
    display: flex;
    align-items: center;
    gap: 12px;
  }
}

.dl-brand {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  text-decoration: none;

  &__mascot {
    width: 42px;
    height: 42px;
    object-fit: contain;
  }

  &__name {
    font-size: 26px;
    font-weight: 800;
    letter-spacing: 0.5px;
    color: $dl-green-dark;
  }
}

.dl-btn-main {
  background: $dl-green;
  color: #ffffff;
  border: none;
  box-shadow: 0 4px 0 $dl-green-dark;
  text-transform: uppercase;
  font-weight: 800;
  letter-spacing: 0.5px;

  &--small {
    padding: 4px 14px;
  }

  &--big {
    box-shadow: 0 6px 0 $dl-green-dark;
  }
}

.dl-btn-ghost {
  color: $dl-ink-dark;
  text-transform: uppercase;
  font-weight: 700;

  &--card {
    background: #ffffff;
    border: 2px solid $dl-gray;
    color: $dl-ink-dark;
    box-shadow: 0 6px 0 #d8d8d8;
  }
}

.dl-hero {
  &__inner {
    max-width: 1100px;
    margin: 0 auto;
    padding: 72px 20px 48px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 40px;
  }

  &__text {
    flex: 1 1 0;
    min-width: 0;
  }

  &__title {
    font-size: clamp(30px, 4.5vw, 46px);
    line-height: 1.12;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0 0 18px;
  }

  &__subtitle {
    font-size: 19px;
    line-height: 1.5;
    color: $dl-ink;
    margin: 0 0 28px;
  }

  &__cta {
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
  }

  &__mascot {
    flex: 0 0 auto;
    width: min(400px, 42vw);
    position: relative;
    display: flex;
    justify-content: center;

    img {
      width: 100%;
      height: auto;
      object-fit: contain;
      max-height: 420px;
    }
  }

  &__bubble {
    position: absolute;
    top: -14px;
    right: -10px;
    background: $dl-gold;
    color: #3c3c3c;
    font-weight: 800;
    padding: 8px 16px;
    border-radius: 18px;
    box-shadow: 0 4px 0 rgba(0, 0, 0, 0.12);
    white-space: nowrap;
  }
}

.dl-underline {
  color: $dl-green-dark;
  position: relative;
  display: inline-block;

  &::after {
    content: '';
    position: absolute;
    left: 0;
    right: 0;
    bottom: 4px;
    height: 10px;
    background: rgba($dl-gold, 0.6);
    z-index: -1;
  }
}

.dl-promise {
  background: $dl-green;
  color: #ffffff;

  &__inner {
    max-width: 1100px;
    margin: 0 auto;
    padding: 20px;
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 28px;
  }

  &__item {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-weight: 700;
    font-size: 15px;
    letter-spacing: 0.3px;
    text-transform: uppercase;
  }
}

.dl-features {
  &__inner {
    max-width: 1100px;
    margin: 0 auto;
    padding: 64px 20px;
  }

  &__grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 20px;
    margin-top: 32px;
  }
}

.dl-section-title {
  text-align: center;
  font-size: 32px;
  font-weight: 800;
  color: $dl-ink-dark;
  margin: 0;
}

.dl-card {
  background: #ffffff;
  border: 2px solid $dl-gray;
  border-radius: 18px;
  padding: 26px 22px;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;

  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.08);
  }

  &__icon {
    width: 52px;
    height: 52px;
    border-radius: 14px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 16px;

    .q-icon {
      font-size: 30px;
      color: #ffffff;
    }

    &--green {
      background: $dl-green;
    }

    &--blue {
      background: $dl-blue;
    }

    &--gold {
      background: $dl-gold;
    }

    &--purple {
      background: #ce82ff;
    }
  }

  &__title {
    font-size: 19px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0 0 8px;
  }

  &__text {
    font-size: 15px;
    line-height: 1.5;
    color: $dl-ink;
    margin: 0;
  }
}

.dl-path {
  background: #f0fff2;

  &__inner {
    max-width: 1100px;
    margin: 0 auto;
    padding: 64px 20px;
  }

  &__lead {
    text-align: center;
    font-size: 17px;
    color: $dl-ink;
    margin: 12px auto 32px;
    max-width: 560px;
  }

  &__demo {
    display: flex;
    gap: 48px;
    align-items: center;
    justify-content: center;
    flex-wrap: wrap;
  }

  &__copy {
    max-width: 460px;
  }

  &__title {
    font-size: 24px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0 0 16px;
  }

  &__list {
    padding-left: 20px;
    color: $dl-ink;
    font-size: 16px;
    line-height: 1.7;
    margin: 0;
  }
}

.dl-demo {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0 8px 8px;

  &__head {
    width: 96px;
    height: 96px;
    border-radius: 50%;
    background: #ffffff;
    border: 3px solid $dl-gold;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    margin-bottom: 4px;
  }

  &__mascot {
    width: 88px;
    height: 88px;
    object-fit: contain;
  }

  &__line {
    width: 6px;
    flex: 1;
    min-height: 18px;
    background: linear-gradient(to bottom, $dl-gray, $dl-gray);
  }

  &__node {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    margin-bottom: 6px;
  }

  &__circle {
    width: 58px;
    height: 58px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: $dl-green;
    color: #ffffff;
    box-shadow: 0 4px 0 $dl-green-dark;
  }

  &__node--current {
    .dl-demo__circle {
      background: $dl-blue;
      box-shadow: 0 4px 0 #1899d6;
      animation: dl-pulse 1.6s ease-in-out infinite;
    }
  }

  &__node--locked {
    .dl-demo__circle {
      background: $dl-gray;
      color: #afafaf;
      box-shadow: 0 4px 0 #cfcfcf;
    }
  }

  &__label {
    font-size: 13px;
    font-weight: 800;
    text-align: center;
    color: $dl-ink-dark;
  }
}

@keyframes dl-pulse {
  0%,
  100% {
    transform: scale(1);
    box-shadow:
      0 4px 0 #1899d6,
      0 0 0 0 rgba(28, 176, 246, 0.5);
  }

  50% {
    transform: scale(1.06);
    box-shadow:
      0 4px 0 #1899d6,
      0 0 0 14px rgba(28, 176, 246, 0);
  }
}

.dl-footer {
  border-top: 2px solid $dl-gray;

  &__inner {
    max-width: 1100px;
    margin: 0 auto;
    padding: 28px 20px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
  }

  &__note {
    margin: 0;
    font-size: 14px;
    color: #8a8a8a;
  }
}

@media (max-width: 760px) {
  .dl-header__actions .dl-btn-ghost {
    display: none;
  }

  .dl-hero__inner {
    flex-direction: column-reverse;
    padding-top: 40px;
    text-align: center;
  }

  .dl-hero__mascot {
    width: 70vw;
    max-width: 320px;

    img {
      max-height: 260px;
    }
  }

  .dl-hero__bubble {
    right: -4px;
  }

  .dl-hero__cta {
    justify-content: center;
  }
}
</style>
