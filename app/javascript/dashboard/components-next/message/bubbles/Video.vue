<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import BaseBubble from './Base.vue';
import Icon from 'next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useLoadWithRetry } from 'dashboard/composables/loadWithRetry';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';
import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';
import { ATTACHMENT_TYPES } from '../constants';
import { formatBytes } from 'shared/helpers/FileHelper';

const showGallery = ref(false);
const { filteredCurrentChatAttachments, attachments } = useMessageContext();

const attachment = computed(() => {
  return attachments.value[0];
});

const formattedFileSize = computed(() => {
  const size = attachment.value?.fileSize || attachment.value?.file_size;
  return size ? `(${formatBytes(size, 1)})` : '';
});

const isReel = computed(() => {
  return attachment.value.fileType === ATTACHMENT_TYPES.IG_REEL;
});

const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry({
  type: 'video',
});

onMounted(() => {
  if (attachment.value?.dataUrl) {
    loadWithRetry(attachment.value.dataUrl);
  }
});

watch(
  () => attachment.value?.dataUrl,
  newUrl => {
    if (newUrl) {
      loadWithRetry(newUrl);
    }
  }
);

const handleError = () => {
  hasError.value = true;
};
</script>

<template>
  <BaseBubble
    class="overflow-hidden p-3"
    data-bubble-name="video"
    @click="showGallery = true"
  >
    <div v-if="hasError" class="flex flex-col gap-2 rounded-lg">
      <div class="flex items-center gap-1.5 text-center">
        <Icon icon="i-lucide-circle-off" class="text-n-slate-11 shrink-0" />
        <p class="mb-0 text-n-slate-11">
          {{ $t('COMPONENTS.MEDIA.VIDEO_UNAVAILABLE') }}
        </p>
      </div>
      <a
        v-if="attachment?.dataUrl"
        :href="attachment.dataUrl"
        target="_blank"
        rel="noreferrer noopener nofollow"
        class="inline-flex items-center gap-1.5 text-xs font-medium text-n-slate-12 underline hover:opacity-80"
        @click.stop
      >
        <Icon icon="i-lucide-external-link" class="size-3.5 shrink-0" />
        <span>{{ $t('COMPONENTS.MEDIA.OPEN_MEDIA') }}</span>
        <span v-if="formattedFileSize">{{ formattedFileSize }}</span>
      </a>
    </div>
    <div v-else-if="isLoaded" class="relative group rounded-lg overflow-hidden">
      <div
        v-if="isReel"
        class="absolute p-2 flex items-start justify-end right-0 pointer-events-none"
      >
        <Icon icon="i-lucide-instagram" class="text-white shadow-lg" />
      </div>
      <video
        controls
        class="rounded-lg skip-context-menu"
        :src="attachment.dataUrl"
        :class="{
          'max-w-48': isReel,
          'max-w-full': !isReel,
        }"
        @click.stop
        @error="handleError"
      />
    </div>
    <div
      v-else
      class="flex items-center justify-between gap-3 px-3 py-2.5 rounded-lg bg-n-alpha-1 min-w-52"
    >
      <div class="flex items-center gap-2 min-w-0">
        <Spinner :size="16" class="text-n-slate-11 shrink-0" />
        <span class="text-xs text-n-slate-11 truncate">
          {{ $t('COMPONENTS.MEDIA.LOADING_VIDEO') }}
        </span>
        <span v-if="formattedFileSize" class="text-xs text-n-slate-10 shrink-0">
          {{ formattedFileSize }}
        </span>
      </div>
      <a
        v-if="attachment?.dataUrl"
        :href="attachment.dataUrl"
        target="_blank"
        rel="noreferrer noopener nofollow"
        class="inline-flex items-center gap-1 text-xs font-medium text-n-slate-12 hover:underline shrink-0"
        @click.stop
      >
        <Icon icon="i-lucide-download" class="size-3.5" />
      </a>
    </div>
  </BaseBubble>
  <GalleryView
    v-if="showGallery"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @error="handleError"
    @close="() => (showGallery = false)"
  />
</template>
