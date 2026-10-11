<script setup>
import { ref, watch } from 'vue';
import WebhookPathPicker from './WebhookPathPicker.vue';

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
});

const emit = defineEmits(['change']);

const SELECT_CLASS =
  'reset-base h-8 m-0 w-full py-0 ps-2 pe-7 text-xs rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12';

const localRows = ref([]);
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
};

const updateRow = (index, key, value) => {
  commit(
    localRows.value.map((row, rowIndex) =>
      rowIndex === index ? { ...row, [key]: value } : row
    )
  );
};

const addRow = () => {
  commit([
    ...localRows.value,
    { attribute_key: '', source_path: props.fields[0]?.path || '' },
  ]);
};

const removeRow = index => {
  commit(localRows.value.filter((_, rowIndex) => rowIndex !== index));
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="space-y-2">
    <div class="flex items-center justify-between gap-2">
      <p class="text-xs font-medium text-n-slate-12">Salvar no contato</p>
      <button
        type="button"
        class="h-7 px-2 rounded-lg text-xs font-medium text-n-brand hover:bg-n-alpha-2 disabled:opacity-40"
        :disabled="!attributes.length"
        @click="addRow"
      >
        Adicionar
      </button>
    </div>
    <p class="text-[0.6875rem] text-n-slate-11">
      O valor recebido no webhook é gravado no atributo personalizado do
      contato.
    </p>
    <p v-if="!attributes.length" class="text-[0.6875rem] text-n-amber-11">
      Nenhum atributo de contato cadastrado. Crie em Configurações → Atributos
      personalizados.
    </p>
    <p v-else-if="!fields.length" class="text-[0.6875rem] text-n-slate-11">
      Escute um teste para escolher de qual campo do webhook vem o valor.
    </p>
    <div
      v-for="(row, index) in localRows"
      :key="index"
      class="grid grid-cols-[1fr_1fr_auto] gap-1.5 items-center"
    >
      <select
        :value="row.attribute_key || ''"
        :class="SELECT_CLASS"
        @change="updateRow(index, 'attribute_key', $event.target.value)"
      >
        <option value="" disabled>Atributo</option>
        <option
          v-for="attr in attributes"
          :key="attr.id"
          :value="attr.attribute_key"
        >
          {{ attr.attribute_display_name }}
        </option>
      </select>
      <WebhookPathPicker
        :model-value="row.source_path || ''"
        :fields="fields"
        placeholder="Campo do JSON"
        @update:model-value="updateRow(index, 'source_path', $event)"
      />
      <button
        type="button"
        class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-ruby-11 hover:bg-n-alpha-2"
        title="Remover"
        @click="removeRow(index)"
      >
        <span class="i-lucide-x size-3.5" />
      </button>
    </div>
  </div>
</template>
