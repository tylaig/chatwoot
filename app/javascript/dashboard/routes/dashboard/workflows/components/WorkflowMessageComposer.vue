<script setup>
import { computed, nextTick, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import WorkflowsAPI from 'dashboard/api/workflows';
import WorkflowVariableInput from './WorkflowVariableInput.vue';

const props = defineProps({
  content: {
    type: String,
    default: '',
  },
  privateNote: {
    type: Boolean,
    default: false,
  },
  attachments: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'updateContent',
  'updatePrivate',
  'updateAttachments',
]);

const MAX_FILES = 10;
const MAX_BYTES = 16 * 1024 * 1024;
const MEDIA_KINDS = [
  {
    id: 'image',
    label: 'Foto',
    icon: 'i-lucide-image',
    accept: 'image/jpeg,image/png,image/gif,image/webp,image/bmp',
  },
  {
    id: 'video',
    label: 'Vídeo',
    icon: 'i-lucide-video',
    accept: 'video/mp4,video/webm,video/ogg,video/quicktime',
  },
  {
    id: 'audio',
    label: 'Áudio',
    icon: 'i-lucide-mic',
    accept: 'audio/mpeg,audio/mp4,audio/ogg,audio/wav,audio/webm,audio/aac',
  },
  {
    id: 'file',
    label: 'Arquivo',
    icon: 'i-lucide-paperclip',
    accept:
      '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.zip,.rar,.json,.xml',
  },
];

const fileInput = ref(null);
const activeKind = ref(MEDIA_KINDS[0]);
const isUploading = ref(false);

const accept = computed(() => activeKind.value.accept);

const fileUrl = data =>
  data.file_url?.startsWith('http')
    ? data.file_url
    : `${window.location.origin}${data.file_url}`;

const matchesKind = (file, kind) => {
  if (kind.accept.includes('.')) {
    const extension = file.name.split('.').pop()?.toLowerCase();
    return kind.accept.split(',').includes(`.${extension}`);
  }
  return kind.accept.split(',').includes(file.type);
};

const pickKind = async kind => {
  if (props.attachments.length >= MAX_FILES) {
    useAlert('A conversa aceita até 10 anexos nesta mensagem.');
    return;
  }
  activeKind.value = kind;
  await nextTick();
  fileInput.value?.click();
};

const upload = async event => {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file) return;
  if (!matchesKind(file, activeKind.value)) {
    useAlert(
      `Envie um arquivo do tipo ${activeKind.value.label.toLowerCase()}.`
    );
    return;
  }
  if (file.size > MAX_BYTES) {
    useAlert('O arquivo passa de 16 MB.');
    return;
  }

  isUploading.value = true;
  try {
    const { data } = await WorkflowsAPI.uploadMedia(file);
    emit('updateAttachments', [
      ...props.attachments,
      {
        blob_id: data.blob_id,
        filename: file.name,
        content_type: file.type,
        file_type: activeKind.value.id,
        preview_url: fileUrl(data),
      },
    ]);
  } catch (error) {
    useAlert(
      error.response?.data?.error || 'Não foi possível enviar o arquivo.'
    );
  } finally {
    isUploading.value = false;
  }
};

const removeAttachment = index => {
  emit(
    'updateAttachments',
    props.attachments.filter((_, itemIndex) => itemIndex !== index)
  );
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="space-y-4">
    <div>
      <p class="mb-1.5 text-xs font-medium text-n-slate-12">Enviar como</p>
      <div class="grid grid-cols-2 gap-2">
        <button
          type="button"
          class="h-9 rounded-lg border text-xs font-medium"
          :class="
            privateNote
              ? 'border-n-weak text-n-slate-11'
              : 'border-n-brand bg-n-brand/10 text-n-brand'
          "
          @click="emit('updatePrivate', false)"
        >
          Resposta
        </button>
        <button
          type="button"
          class="h-9 rounded-lg border text-xs font-medium"
          :class="
            privateNote
              ? 'border-n-amber-9 bg-n-amber-9/10 text-n-amber-11'
              : 'border-n-weak text-n-slate-11'
          "
          @click="emit('updatePrivate', true)"
        >
          Nota privada
        </button>
      </div>
    </div>

    <div>
      <label class="mb-1.5 block text-xs font-medium text-n-slate-12">
        Mensagem
      </label>
      <WorkflowVariableInput
        :model-value="content"
        formatting
        multiline
        :rows="4"
        placeholder="Digite a mensagem. Use {{ para inserir variáveis."
        @update:model-value="emit('updateContent', $event)"
      />
      <p class="mt-1 text-[0.6875rem] text-n-slate-10">
        O texto acompanha a foto, o vídeo, o áudio ou o arquivo, como a legenda
        no envio da conversa.
      </p>
    </div>

    <div class="space-y-2">
      <p class="text-xs font-medium text-n-slate-12">Anexos</p>
      <div
        v-for="(file, index) in attachments"
        :key="`${file.blob_id}-${index}`"
        class="flex items-center gap-2 rounded-lg bg-n-alpha-1 p-2"
      >
        <img
          v-if="file.file_type === 'image' && file.preview_url"
          :src="file.preview_url"
          alt=""
          class="size-10 shrink-0 rounded-md object-cover"
        />
        <span
          v-else
          class="flex size-10 shrink-0 items-center justify-center rounded-md bg-n-alpha-2 text-n-slate-11"
          :class="
            MEDIA_KINDS.find(kind => kind.id === file.file_type)?.icon ||
            'i-lucide-paperclip'
          "
        />
        <span class="min-w-0 flex-1 truncate text-xs text-n-slate-12">
          {{ file.filename }}
        </span>
        <button
          type="button"
          class="flex size-7 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-ruby-11"
          title="Remover anexo"
          @click="removeAttachment(index)"
        >
          <span class="i-lucide-trash-2 size-3.5" />
        </button>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <button
          v-for="kind in MEDIA_KINDS"
          :key="kind.id"
          type="button"
          class="flex h-9 items-center justify-center gap-1.5 rounded-lg border border-n-weak text-xs font-medium text-n-slate-12 hover:border-n-brand hover:text-n-brand disabled:opacity-50"
          :disabled="isUploading"
          @click="pickKind(kind)"
        >
          <span class="size-3.5" :class="kind.icon" />
          {{ kind.label }}
        </button>
      </div>
      <input
        ref="fileInput"
        type="file"
        class="hidden"
        :accept="accept"
        @change="upload"
      />
      <p class="text-[0.6875rem] text-n-slate-10">
        {{
          isUploading
            ? 'Enviando para o armazenamento...'
            : 'Foto, vídeo, áudio e arquivo ficam no armazenamento do Chatwoot. Até 16 MB cada.'
        }}
      </p>
    </div>
  </div>
</template>
