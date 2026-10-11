<script setup>
import { nextTick, ref, watch } from 'vue';
import { OnClickOutside } from '@vueuse/components';
import WebhookPathPicker from './WebhookPathPicker.vue';
import { coerceSample, sampleFor } from '../webhookMapping';

const props = defineProps({
  rows: {
    type: Array,
    default: () => [],
  },
  attributes: {
    type: Array,
    default: () => [],
  },
  fields: {
    type: Array,
    default: () => [],
  },
  title: {
    type: String,
    default: 'Salvar no contato',
  },
  description: {
    type: String,
    default:
      'O valor recebido no webhook é gravado no atributo personalizado do contato.',
  },
  emptyText: {
    type: String,
    default:
      'Nenhum atributo de contato cadastrado. Crie em Configurações → Atributos personalizados.',
  },
});

const emit = defineEmits(['change', 'focus']);

const localRows = ref([]);
const openIndex = ref(-1);
let editing = false;

watch(
  () => JSON.stringify(props.rows || []),
  value => {
    if (editing) return;
    localRows.value = JSON.parse(value).map(row => ({ ...row }));
  },
  { immediate: true }
);

const commit = rows => {
  editing = true;
  localRows.value = rows.map(row => ({ ...row }));
  emit('change', localRows.value);
  nextTick(() => {
    editing = false;
  });
};

const updateRow = (index, key, value) => {
  commit(
    localRows.value.map((row, rowIndex) =>
      rowIndex === index ? { ...row, [key]: value } : row
    )
  );
};

const addRow = () => {
  commit([...localRows.value, { attribute_key: '', source_path: '' }]);
};

const removeRow = index => {
  commit(localRows.value.filter((_, rowIndex) => rowIndex !== index));
};

const attributeName = row =>
  props.attributes.find(item => item.attribute_key === row.attribute_key)
    ?.attribute_display_name || '';

const chooseAttribute = (index, key) => {
  updateRow(index, 'attribute_key', key);
  openIndex.value = -1;
};

const rowPreview = row => {
  const sample = sampleFor(props.fields, row.source_path);
  const attribute = props.attributes.find(
    item => item.attribute_key === row.attribute_key
  );
  return coerceSample(attribute?.attribute_display_type, sample);
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="space-y-2">
    <div class="flex items-center justify-between gap-2">
      <p class="text-xs font-medium text-n-slate-12">{{ title }}</p>
      <button
        type="button"
        class="h-7 px-2 rounded-lg text-xs font-medium text-n-brand hover:bg-n-alpha-2 disabled:opacity-40"
        :disabled="!attributes.length"
        @click="addRow"
      >
        Adicionar
      </button>
    </div>
    <p class="text-[0.6875rem] text-n-slate-11">{{ description }}</p>
    <p v-if="!attributes.length" class="text-[0.6875rem] text-n-amber-11">
      {{ emptyText }}
    </p>
    <p v-else-if="!fields.length" class="text-[0.6875rem] text-n-slate-11">
      Escute um teste para escolher de qual campo do webhook vem o valor.
    </p>
    <div
      v-for="(row, index) in localRows"
      :key="index"
      class="grid grid-cols-[1fr_1fr_auto] gap-1.5 items-center"
    >
      <OnClickOutside class="relative min-w-0" @trigger="openIndex = -1">
        <button
          type="button"
          class="reset-base relative flex h-8 m-0 w-full items-center py-0 ps-2 pe-7 text-xs text-start rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak text-n-slate-12"
          @click="openIndex = openIndex === index ? -1 : index"
        >
          <span
            class="truncate"
            :class="attributeName(row) ? '' : 'text-n-slate-10'"
          >
            {{ attributeName(row) || 'Atributo' }}
          </span>
          <span
            class="i-lucide-chevron-down pointer-events-none absolute end-2 top-1/2 size-3.5 -translate-y-1/2 text-n-slate-10"
          />
        </button>
        <div
          v-if="openIndex === index"
          class="absolute z-40 top-9 start-0 w-full max-h-48 overflow-auto rounded-lg border border-n-weak bg-n-solid-2 p-1 shadow-xl"
        >
          <button
            v-for="attr in attributes"
            :key="attr.id"
            type="button"
            class="w-full rounded-md px-2 py-1.5 text-start text-xs text-n-slate-12 hover:bg-n-alpha-2"
            :class="
              row.attribute_key === attr.attribute_key ? 'bg-n-alpha-2' : ''
            "
            @mousedown.prevent="chooseAttribute(index, attr.attribute_key)"
          >
            {{ attr.attribute_display_name }}
          </button>
        </div>
      </OnClickOutside>
      <WebhookPathPicker
        :model-value="row.source_path || ''"
        :fields="fields"
        placeholder="Campo do JSON"
        @update:model-value="updateRow(index, 'source_path', $event)"
        @focus="emit('focus', index)"
      />
      <button
        type="button"
        class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-ruby-11 hover:bg-n-alpha-2"
        title="Remover"
        @click="removeRow(index)"
      >
        <span class="i-lucide-x size-3.5" />
      </button>
      <p
        v-if="rowPreview(row)"
        class="col-span-2 truncate font-mono text-[0.625rem]"
        :class="
          rowPreview(row) === 'não é um número'
            ? 'text-n-ruby-11'
            : 'text-n-slate-10'
        "
      >
        exemplo: {{ rowPreview(row) }}
      </p>
    </div>
  </div>
</template>
