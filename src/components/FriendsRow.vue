<template>
  <div class="dl-friends" :class="{ 'dl-friends--compact': compact }">
    <figure v-for="friend in friends" :key="friend.name" class="dl-friend">
      <span v-if="!compact" class="dl-friend__bubble">{{ friend.says }}</span>
      <img :src="friend.img" :alt="friend.alt" class="dl-friend__img" />
      <figcaption class="dl-friend__name">{{ friend.name }}</figcaption>
    </figure>
  </div>
</template>

<script setup>
import usagiImg from '@/assets/usagi.webp'
import chiikawaImg from '@/assets/amigos/chiikawa.svg?no-inline'
import hachiwareImg from '@/assets/amigos/hachiware.svg?no-inline'

defineProps({
  compact: { type: Boolean, default: false }
})

const friends = [
  {
    name: 'Chiikawa',
    img: chiikawaImg,
    alt: 'Chiikawa, amiga de Usagi',
    says: '¡Yo también puedo!'
  },
  {
    name: 'Usagi',
    img: usagiImg,
    alt: 'Usagi, la mascota de CodeLingua',
    says: '¡Yaha! A programar'
  },
  {
    name: 'Hachiware',
    img: hachiwareImg,
    alt: 'Hachiware, amigo de Usagi',
    says: '¡Un paso a la vez!'
  }
]
</script>

<style scoped lang="scss">
.dl-friends {
  display: flex;
  justify-content: center;
  align-items: flex-end;
  gap: 18px;
  flex-wrap: wrap;
}

.dl-friend {
  margin: 0;
  text-align: center;
  width: 150px;
  animation: dl-friend-hop 3.2s ease-in-out infinite;

  &:nth-child(2) {
    animation-delay: 0.4s;
  }

  &:nth-child(3) {
    animation-delay: 0.8s;
  }
}

.dl-friend__img {
  width: 130px;
  height: 130px;
  object-fit: contain;
}

.dl-friend__name {
  font-weight: 800;
  color: #58a700;
  font-size: 15px;
}

.dl-friend__bubble {
  display: inline-block;
  background: #fff;
  border: 2px solid #e5e5e5;
  border-radius: 14px;
  padding: 4px 10px;
  font-size: 13px;
  font-weight: 700;
  color: #4b4b4b;
  margin-bottom: 6px;
}

.dl-friends--compact {
  gap: 4px;

  .dl-friend {
    width: 72px;
  }

  .dl-friend__img {
    width: 64px;
    height: 64px;
  }

  .dl-friend__name {
    font-size: 11px;
  }
}

@keyframes dl-friend-hop {
  0%,
  100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-6px);
  }
}

@media (prefers-reduced-motion: reduce) {
  .dl-friend {
    animation: none;
  }
}
</style>
