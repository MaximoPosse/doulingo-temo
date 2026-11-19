<template>
  <section class="dl-teaser">
    <div class="dl-teaser__inner">
      <div class="dl-teaser__text">
        <span class="dl-teaser__eyebrow">Competencia de la expo</span>
        <h2 class="dl-teaser__title">Gran desafío CodeLingua</h2>
        <p class="dl-teaser__lead">
          Veinte preguntas que suben de dificultad a medida que respondés:
          primero fáciles, después intermedias y al final difíciles. Tenés 3
          vidas: cada error te resta una y con 0 vidas la partida termina. Se
          juega una sola vez y tu puntaje entra al ranking.
        </p>
        <ul class="dl-teaser__facts">
          <li>
            <q-icon name="quiz" size="20px" />
            20 preguntas por intento
          </li>
          <li>
            <q-icon name="trending_up" size="20px" />
            Dificultad creciente
          </li>
          <li>
            <q-icon name="favorite" size="20px" />
            3 vidas: cada error resta una
          </li>
          <li>
            <q-icon name="emoji_events" size="20px" />
            Ranking en vivo
          </li>
        </ul>
        <div class="dl-teaser__actions">
          <q-btn
            no-caps
            unelevated
            class="dl-btn-main dl-btn-main--big"
            label="Ir a la expo"
            :to="{ name: 'expo' }"
          />
          <q-btn
            no-caps
            unelevated
            class="dl-btn-ghost dl-btn-ghost--card"
            label="Ver ranking"
            :to="{ name: 'ranking-publico' }"
          />
        </div>
      </div>
      <img
        :src="partyImg"
        alt="Chiikawa y sus amigos festejando"
        class="dl-teaser__img"
      />
    </div>
  </section>
</template>

<script setup>
import partyImg from '@/assets/amigos/chiikawa-fiesta.webp'
</script>

<style lang="scss" scoped>
.dl-teaser {
  background: #211b0b;
  padding: 56px 0;

  &__inner {
    max-width: var(--ancho, 1100px);
    margin: 0 auto;
    padding: 0 20px;
    display: flex;
    align-items: center;
    gap: 32px;
  }

  &__text {
    flex: 1 1 0;
    min-width: 0;
  }

  &__eyebrow {
    font-size: 13px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    color: $dl-orange;
  }

  &__title {
    margin: 6px 0 10px;
    color: $dl-ink-dark;
  }

  &__lead {
    font-size: 17px;
    line-height: 1.5;
    color: $dl-ink;
    margin: 0 0 16px;
  }

  &__facts {
    list-style: none;
    margin: 0 0 22px;
    padding: 0;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(200px, 100%), 1fr));
    gap: 8px 16px;

    li {
      display: flex;
      align-items: center;
      gap: 8px;
      font-weight: 700;
      color: $dl-ink-dark;
    }

    .q-icon {
      color: $dl-green-dark;
    }
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
  }

  &__img {
    flex: 0 0 auto;
    width: min(300px, 34vw);
    height: auto;
    object-fit: contain;
  }
}

@media (max-width: 760px) {
  .dl-teaser {
    padding: 40px 0;

    &__inner {
      flex-direction: column-reverse;
      text-align: center;
      padding: 0 16px;
      gap: 16px;
    }

    &__facts li {
      justify-content: center;
    }

    &__actions {
      justify-content: center;
    }

    &__img {
      width: min(240px, 70vw);
    }
  }
}

@media (max-width: 420px) {
  .dl-teaser__actions .q-btn {
    width: 100%;
  }
}
</style>
