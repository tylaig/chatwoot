<script setup>
import { computed } from 'vue';
import WorkflowVariableInput from './WorkflowVariableInput.vue';

const props = defineProps({
  type: {
    type: String,
    required: true,
  },
  config: {
    type: Object,
    required: true,
  },
  inboxes: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['updateField']);

const LABEL_CLASS = 'block mb-1.5 text-xs font-medium text-n-slate-12';
const HINT_CLASS = 'mt-1 text-[0.6875rem] text-n-slate-10';
const MEDIA_TYPES = [
  { value: 'image', label: 'Imagem', icon: 'i-lucide-image' },
  { value: 'video', label: 'Vídeo', icon: 'i-lucide-video' },
  { value: 'audio', label: 'Áudio', icon: 'i-lucide-audio-lines' },
  { value: 'document', label: 'Documento', icon: 'i-lucide-file' },
];

const officialInboxes = computed(() =>
  props.inboxes.filter(
    inbox =>
      inbox.channel_type === 'Channel::Whatsapp' &&
      inbox.provider === 'whatsapp_cloud'
  )
);

const buttons = computed(() => props.config.buttons || []);
const rows = computed(() => props.config.rows || []);

const replaceList = (field, items) => emit('updateField', field, items);

const updateItem = (field, items, index, key, value) => {
  replaceList(
    field,
    items.map((item, itemIndex) =>
      itemIndex === index ? { ...item, [key]: value } : item
    )
  );
};

const addButton = () => {
  if (buttons.value.length >= 3) return;
  replaceList('buttons', [
    ...buttons.value,
    { id: `opcao_${buttons.value.length + 1}`, title: '' },
  ]);
};

const addRow = () => {
  if (rows.value.length >= 10) return;
  replaceList('rows', [
    ...rows.value,
    { id: `item_${rows.value.length + 1}`, title: '', description: '' },
  ]);
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="space-y-5">
    <div
      class="p-3 rounded-xl border space-y-1"
      :class="
        officialInboxes.length
          ? 'border-green-500/40 bg-green-500/5'
          : 'border-n-amber-8 bg-n-amber-3'
      "
    >
      <p
        class="flex items-center gap-1.5 text-xs font-semibold text-n-slate-12"
      >
        <span class="i-lucide-shield-check size-3.5 text-green-500" />
        Somente API oficial
      </p>
      <p class="text-[0.6875rem] text-n-slate-11">
        <template v-if="officialInboxes.length">
          Envia na janela de 24h pelas caixas
          {{ officialInboxes.map(inbox => inbox.name).join(', ') }}.
        </template>
        <template v-else>
          Nenhuma caixa usa a API oficial da Meta. Conecte um número WhatsApp
          Cloud para este bloco conseguir enviar.
        </template>
      </p>
    </div>

    <template v-if="type !== 'send_whatsapp_media'">
      <div>
        <label :class="LABEL_CLASS">Texto da mensagem</label>
        <WorkflowVariableInput
          :model-value="config.body"
          multiline
          :rows="3"
          placeholder="Como posso te ajudar?"
          @update:model-value="emit('updateField', 'body', $event)"
        />
        <p :class="HINT_CLASS">Máximo de 1024 caracteres na API da Meta.</p>
      </div>
      <div class="grid grid-cols-2 gap-2">
        <div>
          <label :class="LABEL_CLASS">Cabeçalho</label>
          <WorkflowVariableInput
            :model-value="config.header"
            placeholder="Opcional"
            @update:model-value="emit('updateField', 'header', $event)"
          />
        </div>
        <div>
          <label :class="LABEL_CLASS">Rodapé</label>
          <WorkflowVariableInput
            :model-value="config.footer"
            placeholder="Opcional"
            @update:model-value="emit('updateField', 'footer', $event)"
          />
        </div>
      </div>
    </template>

    <div v-if="type === 'send_whatsapp_buttons'" class="space-y-2">
      <div class="flex items-center justify-between">
        <label class="text-xs font-medium text-n-slate-12">Botões</label>
        <button
          type="button"
          class="h-7 px-2 rounded-lg text-xs font-medium text-n-brand hover:bg-n-alpha-2 disabled:opacity-40"
          :disabled="buttons.length >= 3"
          @click="addButton"
        >
          Adicionar
        </button>
      </div>
      <p :class="HINT_CLASS">
        Até 3 botões, com no máximo 20 caracteres. Cada botão vira uma saída do
        bloco.
      </p>
      <div v-for="(button, index) in buttons" :key="index" class="flex gap-1.5">
        <div class="flex-1 min-w-0">
          <WorkflowVariableInput
            :model-value="button.title"
            :placeholder="`Botão ${index + 1}`"
            @update:model-value="
              updateItem('buttons', buttons, index, 'title', $event)
            "
          />
        </div>
        <button
          type="button"
          class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-ruby-11 hover:bg-n-alpha-2"
          title="Remover botão"
          @click="
            replaceList(
              'buttons',
              buttons.filter((_, itemIndex) => itemIndex !== index)
            )
          "
        >
          <span class="i-lucide-x size-3.5" />
        </button>
      </div>
    </div>

    <template v-else-if="type === 'send_whatsapp_list'">
      <div>
        <label :class="LABEL_CLASS">Botão que abre a lista</label>
        <WorkflowVariableInput
          :model-value="config.button_label"
          placeholder="Ver opções"
          @update:model-value="emit('updateField', 'button_label', $event)"
        />
        <p :class="HINT_CLASS">Máximo de 20 caracteres.</p>
      </div>
      <div class="space-y-2">
        <p :class="HINT_CLASS">Cada opção da lista vira uma saída do bloco.</p>
        <div class="flex items-center justify-between">
          <label class="text-xs font-medium text-n-slate-12">Opções</label>
          <button
            type="button"
            class="h-7 px-2 rounded-lg text-xs font-medium text-n-brand hover:bg-n-alpha-2 disabled:opacity-40"
            :disabled="rows.length >= 10"
            @click="addRow"
          >
            Adicionar
          </button>
        </div>
        <div
          v-for="(row, index) in rows"
          :key="index"
          class="p-2 rounded-xl border border-n-weak space-y-1.5"
        >
          <div class="flex gap-1.5">
            <div class="flex-1 min-w-0">
              <WorkflowVariableInput
                :model-value="row.title"
                placeholder="Título da opção"
                @update:model-value="
                  updateItem('rows', rows, index, 'title', $event)
                "
              />
            </div>
            <button
              type="button"
              class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-ruby-11 hover:bg-n-alpha-2"
              title="Remover opção"
              @click="
                replaceList(
                  'rows',
                  rows.filter((_, itemIndex) => itemIndex !== index)
                )
              "
            >
              <span class="i-lucide-x size-3.5" />
            </button>
          </div>
          <WorkflowVariableInput
            :model-value="row.description"
            placeholder="Descrição opcional"
            @update:model-value="
              updateItem('rows', rows, index, 'description', $event)
            "
          />
        </div>
      </div>
    </template>

    <template v-else>
      <div>
        <label :class="LABEL_CLASS">Tipo de mídia</label>
        <div class="grid grid-cols-2 gap-1.5">
          <button
            v-for="media in MEDIA_TYPES"
            :key="media.value"
            type="button"
            class="h-9 px-2 rounded-lg border text-xs font-medium flex items-center justify-center gap-1.5"
            :class="
              (config.media_type || 'image') === media.value
                ? 'border-n-brand bg-n-brand/5 text-n-slate-12'
                : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-1'
            "
            @click="emit('updateField', 'media_type', media.value)"
          >
            <span class="size-3.5" :class="media.icon" />
            {{ media.label }}
          </button>
        </div>
      </div>
      <div>
        <label :class="LABEL_CLASS">Link https</label>
        <WorkflowVariableInput
          :model-value="config.url"
          mono
          placeholder="https://exemplo.com/arquivo.jpg"
          @update:model-value="emit('updateField', 'url', $event)"
        />
        <p :class="HINT_CLASS">
          A Meta baixa o arquivo por um link público https.
        </p>
      </div>
      <div v-if="config.media_type !== 'audio'">
        <label :class="LABEL_CLASS">Legenda</label>
        <WorkflowVariableInput
          :model-value="config.caption"
          multiline
          :rows="2"
          placeholder="Opcional"
          @update:model-value="emit('updateField', 'caption', $event)"
        />
      </div>
      <div v-if="config.media_type === 'document'">
        <label :class="LABEL_CLASS">Nome do arquivo</label>
        <WorkflowVariableInput
          :model-value="config.filename"
          placeholder="pedido.pdf"
          @update:model-value="emit('updateField', 'filename', $event)"
        />
      </div>
    </template>
  </div>
</template>
