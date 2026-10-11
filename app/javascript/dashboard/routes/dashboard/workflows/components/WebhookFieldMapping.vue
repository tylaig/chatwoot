<script setup>
import { computed, provide, ref } from 'vue';
import WebhookJsonTree from './WebhookJsonTree.vue';
import WebhookPathPicker from './WebhookPathPicker.vue';
import WebhookAttributeMapping from './WebhookAttributeMapping.vue';
import { IDENTITY_FIELDS, mappingWarnings, sampleFor } from '../webhookMapping';

const props = defineProps({
  mapping: {
    type: Object,
    default: () => ({}),
  },
  fields: {
    type: Array,
    default: () => [],
  },
  payload: {
    type: Object,
    default: null,
  },
  contactAttributes: {
    type: Array,
    default: () => [],
  },
  conversationAttributes: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'updateField',
  'updateContactRows',
  'updateConversationRows',
]);

const focused = ref('phone');
const contactFocus = ref(-1);
const conversationFocus = ref(-1);
const pathSetter = ref(null);
provide('registerWebhookPathTarget', setter => {
  pathSetter.value = setter;
});

const hasPayload = computed(
  () => props.payload && Object.keys(props.payload).length > 0
);
const warnings = computed(() =>
  mappingWarnings({ mapping: props.mapping, fields: props.fields })
);

const pickPath = path => {
  if (pathSetter.value) pathSetter.value(path);
};

const onContactFocus = index => {
  focused.value = 'contact';
  contactFocus.value = index;
};

const onConversationFocus = index => {
  focused.value = 'conversation';
  conversationFocus.value = index;
};

const sample = path => sampleFor(props.fields, path);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="space-y-4">
    <div
      v-if="hasPayload"
      class="max-h-48 overflow-auto rounded-xl border border-n-weak p-2"
    >
      <p class="mb-1 px-1 text-[0.6875rem] text-n-slate-11">
        Clique em um campo para preencher
        <span class="font-medium text-n-slate-12">{{
          IDENTITY_FIELDS.find(field => field.focus === focused)?.label ||
          'o campo em foco'
        }}</span>
        .
      </p>
      <WebhookJsonTree :value="payload" @pick="pickPath" />
    </div>
    <p v-else class="text-[0.6875rem] text-n-slate-11">
      O último JSON recebido aparece aqui. Abra Testar e salve um exemplo, ou
      use uma requisição recente.
    </p>

    <div
      v-for="field in IDENTITY_FIELDS"
      :key="field.key"
      class="rounded-lg"
      :class="focused === field.focus ? 'ring-2 ring-n-brand' : ''"
    >
      <label class="mb-1 block text-xs font-medium text-n-slate-12">
        {{ field.label }}
      </label>
      <WebhookPathPicker
        :model-value="mapping[field.key] || ''"
        :fields="fields"
        :placeholder="field.placeholder"
        @focus="focused = field.focus"
        @update:model-value="emit('updateField', field.key, $event)"
      />
      <p
        v-if="sample(mapping[field.key])"
        class="mt-1 truncate font-mono text-[0.625rem] text-n-slate-10"
      >
        exemplo: {{ sample(mapping[field.key]) }}
      </p>
      <p
        v-if="field.key === 'labels_path'"
        class="mt-1 text-[0.6875rem] text-n-slate-10"
      >
        Lista ou texto separado por vírgula. Entram na conversa.
      </p>
    </div>

    <WebhookAttributeMapping
      :rows="mapping.custom_attributes || []"
      :attributes="contactAttributes"
      :fields="fields"
      :focused-index="focused === 'contact' ? contactFocus : -1"
      @focus="onContactFocus"
      @change="emit('updateContactRows', $event)"
    />
    <WebhookAttributeMapping
      title="Salvar na conversa"
      description="O valor recebido no webhook é gravado no atributo personalizado da conversa."
      empty-text="Nenhum atributo de conversa cadastrado. Crie em Configurações → Atributos personalizados."
      :rows="mapping.conversation_attributes || []"
      :attributes="conversationAttributes"
      :fields="fields"
      :focused-index="focused === 'conversation' ? conversationFocus : -1"
      @focus="onConversationFocus"
      @change="emit('updateConversationRows', $event)"
    />

    <div v-if="warnings.length" class="space-y-1">
      <p
        v-for="warning in warnings"
        :key="warning"
        class="flex items-start gap-1 text-[0.6875rem] text-n-ruby-11"
      >
        <span class="i-lucide-circle-alert mt-0.5 size-3 shrink-0" />
        <span>{{ warning }}</span>
      </p>
    </div>
  </div>
</template>
