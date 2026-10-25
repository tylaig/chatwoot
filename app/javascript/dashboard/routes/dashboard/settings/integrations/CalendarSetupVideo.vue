<script setup>
defineProps({
  src: {
    type: String,
    required: true,
  },
  poster: {
    type: String,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
});
</script>

<template>
  <figure
    class="overflow-hidden rounded-2xl border border-[#162936] bg-[#04090D] shadow-lg"
  >
    <video
      :key="src"
      class="block w-full bg-[#04090D] aspect-video object-cover"
      controls
      autoplay
      loop
      muted
      playsinline
      preload="metadata"
      :poster="poster"
      :aria-label="title"
    >
      <source :src="src" type="video/mp4" />
    </video>
    <figcaption class="border-t border-[#132631] bg-[#081218] px-4 py-3">
      <div class="flex items-center gap-2">
        <span class="i-lucide-play-circle size-4 text-emerald-400 shrink-0" />
        <p class="text-xs font-semibold text-[#F8FAFC]">{{ title }}</p>
      </div>
      <p class="mt-1 text-[11px] text-slate-400 leading-relaxed">
        {{ description }}
      </p>
    </figcaption>
  </figure>
</template>
