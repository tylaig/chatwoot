<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useLoadWithRetry } from 'dashboard/composables/loadWithRetry';
import BaseBubble from './Base.vue';
import Button from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';
import { downloadFile } from '@chatwoot/utils';
import { formatBytes } from 'shared/helpers/FileHelper';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

const { t } = useI18n();

const { filteredCurrentChatAttachments, attachments } = useMessageContext();

const attachment = computed(() => {
  return attachments.value[0];
});

const formattedFileSize = computed(() => {
  const size = attachment.value?.fileSize || attachment.value?.file_size;
  return size ? `(${formatBytes(size, 1)})` : '';
});

const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry({
  type: 'image',
});

const showGallery = ref(false);
const isDownloading = ref(false);

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

const downloadAttachment = async () => {
  const { fileType, dataUrl, extension } = attachment.value;
  try {
    isDownloading.value = true;
    await downloadFile({ url: dataUrl, type: fileType, extension });
  } catch (error) {
    useAlert(t('GALLERY_VIEW.ERROR_DOWNLOADING'));
  } finally {
    isDownloading.value = false;
  }
};

const handleImageError = () => {
  hasError.value = true;
};
</script>

<template>
  <BaseBubble
    class="overflow-hidden p-3"
    data-bubble-name="image"
    @click="showGallery = true"
  >
    <div v-if="hasError" class="flex flex-col gap-2 rounded-lg">
      <div class="flex items-center gap-1.5 text-center">
        <Icon icon="i-lucide-circle-off" class="text-n-slate-11 shrink-0" />
        <p class="mb-0 text-n-slate-11">
          {{ $t('COMPONENTS.MEDIA.IMAGE_UNAVAILABLE') }}
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
      <img
        class="skip-context-menu"
        :src="attachment.dataUrl"
        :width="attachment.width"
        :height="attachment.height"
      />
      <div
        class="inset-0 p-2 pointer-events-none absolute bg-gradient-to-tl from-n-slate-12/30 dark:from-n-slate-1/50 via-transparent to-transparent hidden group-hover:flex"
      />
      <div class="absolute right-2 bottom-2 hidden group-hover:flex gap-2">
        <Button xs solid slate icon="i-lucide-expand" class="opacity-60" />
        <Button
          xs
          solid
          slate
          icon="i-lucide-download"
          class="opacity-60"
          :is-loading="isDownloading"
          :disabled="isDownloading"
          @click.stop="downloadAttachment"
        />
      </div>
    </div>
    <div
      v-else
      class="flex items-center justify-between gap-3 px-3 py-2.5 rounded-lg bg-n-alpha-1 min-w-52"
    >
      <div class="flex items-center gap-2 min-w-0">
        <Spinner :size="16" class="text-n-slate-11 shrink-0" />
        <span class="text-xs text-n-slate-11 truncate">
          {{ $t('COMPONENTS.MEDIA.LOADING_IMAGE') }}
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
    @error="handleImageError"
    @close="() => (showGallery = false)"
  />
</template>
