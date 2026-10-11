<script setup>
import { ref, computed, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import WorkflowsAPI from 'dashboard/api/workflows';
import { getNodeDefinition, getCategoryStyle } from '../nodeRegistry';
import { formatVariable } from '../variables';
import WorkflowVariableInput from './WorkflowVariableInput.vue';
import WorkflowWebhookTriggerPanel from './WorkflowWebhookTriggerPanel.vue';
import WorkflowOfficialMessagePanel from './WorkflowOfficialMessagePanel.vue';
import WorkflowMessageComposer from './WorkflowMessageComposer.vue';

const props = defineProps({
  node: {
    type: Object,
    default: null,
  },
  availableTemplates: {
    type: Array,
    default: () => [],
  },
  issues: {
    type: Array,
    default: () => [],
  },
  workflowId: {
    type: [String, Number],
    required: true,
  },
  webhookTrigger: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits([
  'updateConfig',
  'deleteNode',
  'close',
  'openTemplatePicker',
  'updateWebhookTrigger',
]);

const INPUT_CLASS =
  'reset-base w-full h-9 m-0 px-3 text-xs rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10';
const SELECT_CLASS =
  'w-full h-9 m-0 py-0 ps-3 text-xs rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand text-n-slate-12';
const LABEL_CLASS = 'block mb-1.5 text-xs font-medium text-n-slate-12';
const HINT_CLASS = 'mt-1 text-[0.6875rem] text-n-slate-10';
const LINK_BUTTON_CLASS =
  'inline-flex items-center gap-1 text-xs font-medium text-n-brand hover:underline';
const ROUTE_COLORS = ['#3B82F6', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899'];
const OFFICIAL_MESSAGE_TYPES = [
  'send_whatsapp_buttons',
  'send_whatsapp_list',
  'send_whatsapp_media',
];

const OPERATORS = [
  { value: 'equal_to', label: 'é igual a' },
  { value: 'not_equal_to', label: 'é diferente de' },
  { value: 'contains', label: 'contém' },
  { value: 'not_contains', label: 'não contém' },
  { value: 'starts_with', label: 'começa com' },
  { value: 'greater_than', label: 'é maior que' },
  { value: 'less_than', label: 'é menor que' },
  { value: 'is_empty', label: 'está vazio' },
  { value: 'is_not_empty', label: 'não está vazio' },
];
const VALUELESS_OPERATORS = ['is_empty', 'is_not_empty'];

const DELIVERY_MODES = [
  {
    value: 'auto',
    icon: 'i-lucide-sparkles',
    title: 'Automático',
    hint: 'Texto com a janela aberta, template quando fechada.',
  },
  {
    value: 'inside_24h',
    icon: 'i-lucide-message-square-text',
    title: 'Só texto livre',
    hint: 'Exige a janela de 24h aberta.',
  },
  {
    value: 'outside_24h',
    icon: 'i-lucide-layout-template',
    title: 'Só template',
    hint: 'Template aprovado pela Meta.',
  },
];

const inboxes = useMapGetter('inboxes/getInboxes');
const agents = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');
const labels = useMapGetter('labels/getLabels');
const getAttributesByModel = useMapGetter('attributes/getAttributesByModel');

const isTestingHttp = ref(false);
const httpTestResult = ref(null);

watch(
  () => props.node?.id,
  () => {
    httpTestResult.value = null;
  }
);

const nodeMeta = computed(() =>
  props.node ? getNodeDefinition(props.node.type) : null
);
const style = computed(() => getCategoryStyle(props.node?.type));
const config = computed(() => props.node?.config || {});

const updateField = (field, value) => {
  emit('updateConfig', { ...config.value, [field]: value });
};

const updateFields = fields => {
  emit('updateConfig', { ...config.value, ...fields });
};

const updateListItem = (field, index, key, value) => {
  const list = [...(config.value[field] || [])];
  list[index] = { ...list[index], [key]: value };
  updateField(field, list);
};

const removeListItem = (field, index) => {
  const list = [...(config.value[field] || [])];
  list.splice(index, 1);
  updateField(field, list);
};

const addListItem = (field, item) => {
  updateField(field, [...(config.value[field] || []), item]);
};

const addRoute = () => {
  const routes = config.value.routes || [];
  addListItem('routes', {
    name: `Rota ${routes.length + 1}`,
    operator: 'equal_to',
    value: '',
    color: ROUTE_COLORS[routes.length % ROUTE_COLORS.length],
  });
};

const selectedTemplate = computed(() =>
  props.availableTemplates.find(tpl => tpl.name === config.value.template_name)
);

const templatePlaceholders = computed(() => {
  const body = selectedTemplate.value?.body || '';
  return [
    ...new Set(
      [...body.matchAll(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g)].map(m => m[1])
    ),
  ];
});

const templatePreview = computed(() => {
  const body = selectedTemplate.value?.body || '';
  const params = config.value.template_params || {};
  return body.replace(
    /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g,
    (match, key) => params[key] || match
  );
});

const placeholderLabel = key => `{{${key}}}`;

const updateTemplateParam = (key, value) => {
  updateField('template_params', {
    ...(config.value.template_params || {}),
    [key]: value,
  });
};

const showTemplateSelector = computed(() => {
  if (props.node?.type === 'send_whatsapp_template') return true;
  return (config.value.delivery_mode || 'auto') !== 'inside_24h';
});

const attributeOptions = computed(() =>
  getAttributesByModel.value(
    config.value.target === 'conversation'
      ? 'conversation_attribute'
      : 'contact_attribute'
  )
);

const selectAgent = id => {
  const agent = agents.value.find(item => String(item.id) === id);
  updateFields({ agent_id: agent?.id || '', agent_name: agent?.name || '' });
};

const selectTeam = id => {
  const team = teams.value.find(item => String(item.id) === id);
  updateFields({ team_id: team?.id || '', team_name: team?.name || '' });
};

const runHttpTest = async () => {
  isTestingHttp.value = true;
  httpTestResult.value = null;
  const payload =
    props.node.type === 'send_webhook'
      ? {
          method: config.value.method || 'POST',
          url: config.value.url,
          body: config.value.payload,
        }
      : config.value;
  try {
    const res = await WorkflowsAPI.testHttpRequest(payload);
    httpTestResult.value = res.data;
  } catch (err) {
    const data = err.response?.data;
    httpTestResult.value = data?.statusText
      ? data
      : {
          ok: false,
          statusText: data?.error || 'Falha ao testar a requisição',
          duration: '—',
          data: data || { error: err.message },
        };
  } finally {
    isTestingHttp.value = false;
  }
};

const responseVariable = computed(
  () =>
    `vars.${(config.value.save_response_as || 'http_response').replace(/^(workflow|vars?)\./, '')}`
);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/no-root-v-if -->
  <aside
    v-if="node"
    class="w-[24rem] shrink-0 border-s border-n-weak bg-n-solid-1 flex flex-col h-full overflow-hidden z-20 shadow-2xl"
  >
    <div
      class="px-4 py-3 border-b border-n-weak flex items-center justify-between gap-3"
    >
      <div class="flex items-center gap-3 min-w-0">
        <div
          class="size-9 rounded-xl flex items-center justify-center shrink-0"
          :class="[style.soft, style.text]"
        >
          <span class="size-5" :class="nodeMeta.icon" />
        </div>
        <div class="min-w-0">
          <h3 class="text-sm font-semibold text-n-slate-12 truncate">
            {{ nodeMeta.title }}
          </h3>
          <p class="text-xs text-n-slate-11 truncate">
            {{ nodeMeta.subtitle }}
          </p>
        </div>
      </div>
      <button
        type="button"
        class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 shrink-0"
        title="Fechar"
        @click="emit('close')"
      >
        <span class="i-lucide-x size-4" />
      </button>
    </div>

    <div class="flex-1 overflow-y-auto p-4 space-y-5">
      <div
        v-if="issues.length"
        class="p-3 rounded-xl bg-n-ruby-9/10 border border-n-ruby-8/40 space-y-1"
      >
        <p
          class="flex items-center gap-1.5 text-xs font-semibold text-n-ruby-11"
        >
          <span class="i-lucide-circle-alert size-3.5" />
          Corrija antes de publicar
        </p>
        <p v-for="issue in issues" :key="issue" class="text-xs text-n-ruby-11">
          {{ issue }}
        </p>
      </div>

      <div>
        <label :class="LABEL_CLASS">Nome do bloco</label>
        <input
          :value="config.custom_title || ''"
          :placeholder="nodeMeta.title"
          type="text"
          :class="INPUT_CLASS"
          @input="updateField('custom_title', $event.target.value)"
        />
      </div>

      <WorkflowWebhookTriggerPanel
        v-if="node.type === 'webhook_trigger'"
        :workflow-id="workflowId"
        :trigger="webhookTrigger"
        :inboxes="inboxes"
        @update:trigger="emit('updateWebhookTrigger', $event)"
      />

      <WorkflowMessageComposer
        v-else-if="node.type === 'send_message'"
        :content="config.content || ''"
        :private-note="Boolean(config.private)"
        :attachments="config.attachments || []"
        @update-content="updateField('content', $event)"
        @update-private="updateField('private', $event)"
        @update-attachments="updateField('attachments', $event)"
      />

      <template
        v-else-if="
          ['send_whatsapp_message', 'send_whatsapp_template'].includes(
            node.type
          )
        "
      >
        <div v-if="node.type === 'send_whatsapp_message'">
          <label :class="LABEL_CLASS">Modo de envio</label>
          <div class="space-y-1.5">
            <button
              v-for="mode in DELIVERY_MODES"
              :key="mode.value"
              type="button"
              class="w-full flex items-start gap-3 p-2.5 rounded-xl border text-start transition-colors"
              :class="
                (config.delivery_mode || 'auto') === mode.value
                  ? 'border-n-brand bg-n-brand/5'
                  : 'border-n-weak hover:bg-n-alpha-1'
              "
              @click="updateField('delivery_mode', mode.value)"
            >
              <span
                class="size-4 mt-0.5 shrink-0"
                :class="[
                  mode.icon,
                  (config.delivery_mode || 'auto') === mode.value
                    ? 'text-n-brand'
                    : 'text-n-slate-10',
                ]"
              />
              <span>
                <span class="block text-xs font-semibold text-n-slate-12">{{
                  mode.title
                }}</span>
                <span class="block text-[0.6875rem] text-n-slate-11">{{
                  mode.hint
                }}</span>
              </span>
            </button>
          </div>
        </div>

        <div
          v-if="
            node.type === 'send_whatsapp_message' &&
            config.delivery_mode !== 'outside_24h'
          "
        >
          <label :class="LABEL_CLASS">Mensagem de texto</label>
          <WorkflowVariableInput
            :model-value="config.text"
            multiline
            :rows="3"
            placeholder="Olá {{ $contact.first_name }}!"
            @update:model-value="updateField('text', $event)"
          />
        </div>

        <div v-if="showTemplateSelector" class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="text-xs font-medium text-n-slate-12">
              Template aprovado
              <span
                v-if="
                  node.type === 'send_whatsapp_message' &&
                  (config.delivery_mode || 'auto') === 'auto'
                "
                class="text-n-slate-10 font-normal"
              >
                (janela fechada)
              </span>
            </label>
            <button
              type="button"
              :class="LINK_BUTTON_CLASS"
              @click="emit('openTemplatePicker')"
            >
              <span class="i-lucide-layout-template size-3.5" />
              {{ config.template_name ? 'Trocar' : 'Selecionar' }}
            </button>
          </div>
          <div
            v-if="config.template_name"
            class="flex items-center gap-2 px-3 py-2 rounded-lg bg-n-alpha-1"
          >
            <span class="flex-1 font-mono text-xs text-n-slate-12 truncate">{{
              config.template_name
            }}</span>
            <span
              class="px-1.5 py-0.5 rounded-md text-[0.625rem] font-semibold"
              :class="
                selectedTemplate?.status === 'APPROVED'
                  ? 'bg-green-500/15 text-green-700 dark:text-green-300'
                  : 'bg-n-amber-9/15 text-n-amber-11'
              "
            >
              {{ selectedTemplate?.status || 'Não encontrado' }}
            </span>
            <button
              type="button"
              class="flex items-center justify-center size-6 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2"
              title="Remover template"
              @click="updateFields({ template_name: '', template_params: {} })"
            >
              <span class="i-lucide-x size-3.5" />
            </button>
          </div>
          <button
            v-else
            type="button"
            class="w-full h-9 rounded-lg border border-dashed border-n-strong text-xs text-n-slate-11 hover:text-n-slate-12 hover:border-n-brand"
            @click="emit('openTemplatePicker')"
          >
            Nenhum template selecionado
          </button>

          <div v-if="templatePlaceholders.length" class="space-y-2">
            <p class="text-xs font-medium text-n-slate-12">
              Variáveis do template
            </p>
            <div
              v-for="key in templatePlaceholders"
              :key="key"
              class="flex items-center gap-2"
            >
              <span class="w-12 shrink-0 font-mono text-xs text-n-slate-10">{{
                placeholderLabel(key)
              }}</span>
              <div class="flex-1 min-w-0">
                <WorkflowVariableInput
                  :model-value="(config.template_params || {})[key]"
                  placeholder="{{ $contact.first_name }}"
                  @update:model-value="updateTemplateParam(key, $event)"
                />
              </div>
            </div>
          </div>

          <div v-if="templatePreview" class="space-y-1.5">
            <p class="text-xs font-medium text-n-slate-12">Pré-visualização</p>
            <div
              class="p-3 rounded-xl bg-[#E1F8DC] dark:bg-[#1E2C22] text-xs text-slate-900 dark:text-slate-100 whitespace-pre-line leading-relaxed"
            >
              {{ templatePreview }}
            </div>
          </div>
        </div>
      </template>

      <WorkflowOfficialMessagePanel
        v-else-if="OFFICIAL_MESSAGE_TYPES.includes(node.type)"
        :type="node.type"
        :config="config"
        :inboxes="inboxes"
        @update-field="updateField"
      />

      <template v-else-if="node.type === 'condition'">
        <div class="flex items-center justify-between">
          <label class="text-xs font-medium text-n-slate-12">Regras</label>
          <div class="flex p-0.5 rounded-lg bg-n-alpha-1">
            <button
              v-for="option in [
                { value: 'all', label: 'Todas (E)' },
                { value: 'any', label: 'Qualquer (OU)' },
              ]"
              :key="option.value"
              type="button"
              class="px-2 py-1 text-[0.6875rem] font-medium rounded-md"
              :class="
                (config.match_type || 'all') === option.value
                  ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11'
              "
              @click="updateField('match_type', option.value)"
            >
              {{ option.label }}
            </button>
          </div>
        </div>

        <div
          v-for="(rule, idx) in config.conditions || []"
          :key="idx"
          class="p-3 rounded-xl bg-n-alpha-1 space-y-2"
        >
          <div class="flex items-center justify-between">
            <span class="text-[0.6875rem] font-semibold text-n-slate-11"
              >Regra {{ idx + 1 }}</span
            >
            <button
              v-if="(config.conditions || []).length > 1"
              type="button"
              class="flex items-center justify-center size-6 rounded-md text-n-slate-10 hover:text-n-ruby-11 hover:bg-n-ruby-9/10"
              title="Remover regra"
              @click="removeListItem('conditions', idx)"
            >
              <span class="i-lucide-trash-2 size-3.5" />
            </button>
          </div>
          <WorkflowVariableInput
            :model-value="rule.field"
            mode="path"
            mono
            placeholder="Escolha uma variável"
            @update:model-value="
              updateListItem('conditions', idx, 'field', $event)
            "
          />
          <select
            :value="rule.operator || 'equal_to'"
            :class="SELECT_CLASS"
            @change="
              updateListItem('conditions', idx, 'operator', $event.target.value)
            "
          >
            <option v-for="op in OPERATORS" :key="op.value" :value="op.value">
              {{ op.label }}
            </option>
          </select>
          <WorkflowVariableInput
            v-if="!VALUELESS_OPERATORS.includes(rule.operator)"
            :model-value="rule.value"
            placeholder="Valor esperado"
            @update:model-value="
              updateListItem('conditions', idx, 'value', $event)
            "
          />
        </div>

        <button
          type="button"
          :class="LINK_BUTTON_CLASS"
          @click="
            addListItem('conditions', {
              field: '',
              operator: 'equal_to',
              value: '',
            })
          "
        >
          <span class="i-lucide-plus size-3.5" />
          Adicionar regra
        </button>
      </template>

      <template v-else-if="node.type === 'router'">
        <div>
          <label :class="LABEL_CLASS">Rotear pela variável</label>
          <WorkflowVariableInput
            :model-value="config.source_variable"
            mode="path"
            mono
            placeholder="Escolha uma variável"
            @update:model-value="updateField('source_variable', $event)"
          />
        </div>

        <div class="space-y-2">
          <label class="text-xs font-medium text-n-slate-12">Rotas</label>
          <div
            v-for="(rt, idx) in config.routes || []"
            :key="idx"
            class="p-3 rounded-xl bg-n-alpha-1 space-y-2"
          >
            <div class="flex items-center gap-2">
              <span
                class="size-2.5 rounded-full shrink-0"
                :style="{ backgroundColor: rt.color }"
              />
              <input
                :value="rt.name"
                type="text"
                placeholder="Nome da rota"
                :class="INPUT_CLASS"
                @input="
                  updateListItem('routes', idx, 'name', $event.target.value)
                "
              />
              <button
                type="button"
                class="flex items-center justify-center size-8 shrink-0 rounded-md text-n-slate-10 hover:text-n-ruby-11 hover:bg-n-ruby-9/10"
                title="Remover rota"
                @click="removeListItem('routes', idx)"
              >
                <span class="i-lucide-trash-2 size-3.5" />
              </button>
            </div>
            <div class="grid grid-cols-2 gap-2">
              <select
                :value="rt.operator || 'equal_to'"
                :class="SELECT_CLASS"
                @change="
                  updateListItem('routes', idx, 'operator', $event.target.value)
                "
              >
                <option value="equal_to">é igual a</option>
                <option value="not_equal_to">é diferente de</option>
                <option value="contains">contém</option>
              </select>
              <WorkflowVariableInput
                :model-value="rt.value"
                placeholder="Valor"
                @update:model-value="
                  updateListItem('routes', idx, 'value', $event)
                "
              />
            </div>
          </div>
          <button type="button" :class="LINK_BUTTON_CLASS" @click="addRoute">
            <span class="i-lucide-plus size-3.5" />
            Adicionar rota
          </button>
        </div>

        <div>
          <label :class="LABEL_CLASS">Rota padrão</label>
          <input
            :value="config.default_route_name || 'Default'"
            type="text"
            :class="INPUT_CLASS"
            @input="updateField('default_route_name', $event.target.value)"
          />
          <p :class="HINT_CLASS">Seguida quando nenhuma rota corresponder.</p>
        </div>
      </template>

      <template v-else-if="node.type === 'delay'">
        <div>
          <label :class="LABEL_CLASS">Aguardar por</label>
          <div class="grid grid-cols-2 gap-2">
            <input
              :value="config.duration"
              type="number"
              min="1"
              :class="INPUT_CLASS"
              @input="
                updateField('duration', parseInt($event.target.value, 10) || 0)
              "
            />
            <select
              :value="config.unit || 'minutes'"
              :class="SELECT_CLASS"
              @change="updateField('unit', $event.target.value)"
            >
              <option value="seconds">Segundos</option>
              <option value="minutes">Minutos</option>
              <option value="hours">Horas</option>
              <option value="days">Dias</option>
            </select>
          </div>
        </div>
      </template>

      <template v-else-if="node.type === 'wait_until'">
        <div>
          <label :class="LABEL_CLASS">Modo</label>
          <select
            :value="config.wait_mode || 'specific_time'"
            :class="SELECT_CLASS"
            @change="updateField('wait_mode', $event.target.value)"
          >
            <option value="specific_time">Horário específico</option>
            <option value="business_hours">Próximo horário comercial</option>
          </select>
        </div>
        <div v-if="(config.wait_mode || 'specific_time') === 'specific_time'">
          <label :class="LABEL_CLASS">Horário</label>
          <input
            :value="config.target_time || '09:00'"
            type="time"
            :class="INPUT_CLASS"
            @input="updateField('target_time', $event.target.value)"
          />
        </div>
        <div v-else class="grid grid-cols-2 gap-2">
          <div>
            <label :class="LABEL_CLASS">Início</label>
            <input
              :value="config.business_start || '08:00'"
              type="time"
              :class="INPUT_CLASS"
              @input="updateField('business_start', $event.target.value)"
            />
          </div>
          <div>
            <label :class="LABEL_CLASS">Fim</label>
            <input
              :value="config.business_end || '18:00'"
              type="time"
              :class="INPUT_CLASS"
              @input="updateField('business_end', $event.target.value)"
            />
          </div>
        </div>
        <div>
          <label :class="LABEL_CLASS">Fuso horário</label>
          <input
            :value="config.timezone || 'America/Sao_Paulo'"
            type="text"
            :class="INPUT_CLASS"
            @input="updateField('timezone', $event.target.value)"
          />
        </div>
      </template>

      <template v-else-if="node.type === 'wait_for_reply'">
        <div>
          <label :class="LABEL_CLASS">Tempo limite (horas)</label>
          <input
            :value="config.timeout_hours"
            type="number"
            min="1"
            :class="INPUT_CLASS"
            @input="
              updateField(
                'timeout_hours',
                parseInt($event.target.value, 10) || 0
              )
            "
          />
          <p :class="HINT_CLASS">
            Sem resposta nesse prazo, o fluxo segue pela saída "Sem resposta".
          </p>
        </div>
        <div class="space-y-2">
          <label
            v-for="option in [
              {
                key: 'ignore_bot_messages',
                label: 'Ignorar mensagens de bots',
              },
              { key: 'ignore_private_notes', label: 'Ignorar notas privadas' },
              {
                key: 'only_customer_messages',
                label: 'Apenas mensagens do cliente',
              },
            ]"
            :key="option.key"
            class="flex items-center gap-2 text-xs text-n-slate-12 cursor-pointer"
          >
            <input
              type="checkbox"
              :checked="config[option.key] !== false"
              @change="updateField(option.key, $event.target.checked)"
            />
            {{ option.label }}
          </label>
        </div>
      </template>

      <template v-else-if="node.type === 'set_variable'">
        <div>
          <label :class="LABEL_CLASS">Nome da variável</label>
          <input
            :value="config.variable_name"
            type="text"
            placeholder="lead_score"
            class="font-mono"
            :class="[INPUT_CLASS]"
            @input="
              updateField(
                'variable_name',
                $event.target.value.replace(/[^a-zA-Z0-9_]/g, '_')
              )
            "
          />
          <p :class="HINT_CLASS">
            Use depois como
            <span class="font-mono text-n-iris-11">{{
              formatVariable(`vars.${config.variable_name || 'nome'}`)
            }}</span>
          </p>
        </div>
        <div>
          <label :class="LABEL_CLASS">Tipo</label>
          <select
            :value="config.variable_type || 'string'"
            :class="SELECT_CLASS"
            @change="updateField('variable_type', $event.target.value)"
          >
            <option value="string">Texto</option>
            <option value="number">Número</option>
            <option value="boolean">Verdadeiro/Falso</option>
            <option value="json">JSON</option>
          </select>
        </div>
        <div>
          <label :class="LABEL_CLASS">Valor</label>
          <WorkflowVariableInput
            :model-value="config.variable_value"
            placeholder="Texto fixo ou {{ $variavel }}"
            @update:model-value="updateField('variable_value', $event)"
          />
        </div>
      </template>

      <template v-else-if="['add_tag', 'remove_tag'].includes(node.type)">
        <div>
          <label :class="LABEL_CLASS">Etiqueta</label>
          <select
            :value="config.tag_name || ''"
            :class="SELECT_CLASS"
            @change="updateField('tag_name', $event.target.value)"
          >
            <option value="" disabled>Selecione uma etiqueta</option>
            <option
              v-for="label in labels"
              :key="label.id"
              :value="label.title"
            >
              {{ label.title }}
            </option>
          </select>
          <p v-if="!labels.length" :class="HINT_CLASS">
            Nenhuma etiqueta cadastrada. Crie em Configurações → Etiquetas.
          </p>
        </div>
      </template>

      <template v-else-if="node.type === 'update_contact'">
        <div>
          <label :class="LABEL_CLASS">Campo do contato</label>
          <select
            :value="config.field_name || 'name'"
            :class="SELECT_CLASS"
            @change="updateField('field_name', $event.target.value)"
          >
            <option value="name">Nome</option>
            <option value="email">E-mail</option>
            <option value="phone_number">Telefone</option>
            <option value="identifier">Identificador externo</option>
          </select>
        </div>
        <div>
          <label :class="LABEL_CLASS">Novo valor</label>
          <WorkflowVariableInput
            :model-value="config.field_value"
            placeholder="{{ $webhook.customer.name }}"
            @update:model-value="updateField('field_value', $event)"
          />
        </div>
      </template>

      <template v-else-if="node.type === 'update_custom_attribute'">
        <div>
          <label :class="LABEL_CLASS">Aplicar em</label>
          <select
            :value="config.target || 'contact'"
            :class="SELECT_CLASS"
            @change="
              updateFields({ target: $event.target.value, attribute_key: '' })
            "
          >
            <option value="contact">Contato</option>
            <option value="conversation">Conversa</option>
          </select>
        </div>
        <div>
          <label :class="LABEL_CLASS">Atributo</label>
          <select
            :value="config.attribute_key || ''"
            :class="SELECT_CLASS"
            @change="updateField('attribute_key', $event.target.value)"
          >
            <option value="" disabled>Selecione um atributo</option>
            <option
              v-for="attr in attributeOptions"
              :key="attr.id"
              :value="attr.attribute_key"
            >
              {{ attr.attribute_display_name }}
            </option>
          </select>
          <p v-if="!attributeOptions.length" :class="HINT_CLASS">
            Nenhum atributo personalizado cadastrado.
          </p>
        </div>
        <div>
          <label :class="LABEL_CLASS">Valor</label>
          <WorkflowVariableInput
            :model-value="config.attribute_value"
            placeholder="{{ $webhook.customer.email }}"
            @update:model-value="updateField('attribute_value', $event)"
          />
          <p :class="HINT_CLASS">
            Abra as variáveis e escolha um campo do webhook, ou escreva um valor
            fixo.
          </p>
        </div>
      </template>

      <template v-else-if="node.type === 'update_conversation'">
        <div>
          <label :class="LABEL_CLASS">Prioridade</label>
          <select
            :value="config.priority || 'high'"
            :class="SELECT_CLASS"
            @change="updateField('priority', $event.target.value)"
          >
            <option value="urgent">Urgente</option>
            <option value="high">Alta</option>
            <option value="medium">Média</option>
            <option value="low">Baixa</option>
          </select>
        </div>
        <div>
          <label :class="LABEL_CLASS">Status</label>
          <select
            :value="config.status || 'open'"
            :class="SELECT_CLASS"
            @change="updateField('status', $event.target.value)"
          >
            <option value="open">Aberta</option>
            <option value="pending">Pendente</option>
            <option value="snoozed">Adiada</option>
            <option value="resolved">Resolvida</option>
          </select>
        </div>
      </template>

      <template v-else-if="node.type === 'assign_agent'">
        <div>
          <label :class="LABEL_CLASS">Agente</label>
          <select
            :value="String(config.agent_id || '')"
            :class="SELECT_CLASS"
            @change="selectAgent($event.target.value)"
          >
            <option value="" disabled>Selecione um agente</option>
            <option
              v-for="agent in agents"
              :key="agent.id"
              :value="String(agent.id)"
            >
              {{ agent.name }}
            </option>
          </select>
        </div>
      </template>

      <template v-else-if="node.type === 'assign_team'">
        <div>
          <label :class="LABEL_CLASS">Time</label>
          <select
            :value="String(config.team_id || '')"
            :class="SELECT_CLASS"
            @change="selectTeam($event.target.value)"
          >
            <option value="" disabled>Selecione um time</option>
            <option
              v-for="team in teams"
              :key="team.id"
              :value="String(team.id)"
            >
              {{ team.name }}
            </option>
          </select>
          <p v-if="!teams.length" :class="HINT_CLASS">
            Nenhum time cadastrado.
          </p>
        </div>
      </template>

      <template v-else-if="node.type === 'add_private_note'">
        <div>
          <label :class="LABEL_CLASS">Nota</label>
          <WorkflowVariableInput
            :model-value="config.note_text"
            multiline
            :rows="4"
            placeholder="Visível apenas para a equipe"
            @update:model-value="updateField('note_text', $event)"
          />
          <p :class="HINT_CLASS">A nota fica visível apenas para a equipe.</p>
        </div>
      </template>

      <div
        v-else-if="
          ['resolve_conversation', 'reopen_conversation'].includes(node.type)
        "
        class="flex gap-3 p-3 rounded-xl bg-n-alpha-1"
      >
        <span
          class="size-4 mt-0.5 shrink-0"
          :class="[nodeMeta.icon, style.text]"
        />
        <p class="text-xs text-n-slate-11">
          {{
            node.type === 'resolve_conversation'
              ? 'Ao chegar neste bloco a conversa atual é marcada como resolvida.'
              : 'Ao chegar neste bloco a conversa é reaberta para a equipe.'
          }}
        </p>
      </div>

      <template
        v-else-if="['http_request', 'send_webhook'].includes(node.type)"
      >
        <div class="grid grid-cols-[6rem_1fr] gap-2">
          <div>
            <label :class="LABEL_CLASS">Método</label>
            <select
              :value="config.method || 'POST'"
              :class="SELECT_CLASS"
              @change="updateField('method', $event.target.value)"
            >
              <option
                v-for="method in node.type === 'send_webhook'
                  ? ['POST', 'PUT']
                  : ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']"
                :key="method"
                :value="method"
              >
                {{ method }}
              </option>
            </select>
          </div>
          <div class="min-w-0">
            <label :class="LABEL_CLASS">URL</label>
            <WorkflowVariableInput
              :model-value="config.url"
              mono
              placeholder="https://api.exemplo.com"
              @update:model-value="updateField('url', $event)"
            />
          </div>
        </div>

        <template v-if="node.type === 'http_request'">
          <div
            v-for="listField in [
              { key: 'params', title: 'Query params' },
              { key: 'headers', title: 'Headers' },
            ]"
            :key="listField.key"
          >
            <div class="flex items-center justify-between mb-1.5">
              <label class="text-xs font-medium text-n-slate-12">{{
                listField.title
              }}</label>
              <button
                type="button"
                :class="LINK_BUTTON_CLASS"
                @click="addListItem(listField.key, { key: '', value: '' })"
              >
                <span class="i-lucide-plus size-3.5" />
                Adicionar
              </button>
            </div>
            <div class="space-y-1.5">
              <div
                v-for="(pair, i) in config[listField.key] || []"
                :key="i"
                class="grid grid-cols-[1fr_1.4fr_auto] gap-1.5 items-start"
              >
                <input
                  :value="pair.key"
                  placeholder="Chave"
                  class="font-mono"
                  :class="[INPUT_CLASS]"
                  @input="
                    updateListItem(listField.key, i, 'key', $event.target.value)
                  "
                />
                <WorkflowVariableInput
                  :model-value="pair.value"
                  mono
                  placeholder="Valor"
                  @update:model-value="
                    updateListItem(listField.key, i, 'value', $event)
                  "
                />
                <button
                  type="button"
                  class="flex items-center justify-center size-9 rounded-md text-n-slate-10 hover:text-n-ruby-11 hover:bg-n-ruby-9/10"
                  title="Remover"
                  @click="removeListItem(listField.key, i)"
                >
                  <span class="i-lucide-x size-3.5" />
                </button>
              </div>
            </div>
          </div>

          <div>
            <label :class="LABEL_CLASS">Autenticação</label>
            <select
              :value="config.auth_type || 'none'"
              :class="SELECT_CLASS"
              @change="updateField('auth_type', $event.target.value)"
            >
              <option value="none">Nenhuma</option>
              <option value="bearer">Bearer token</option>
              <option value="basic">Basic auth</option>
              <option value="api_key">Header X-API-Key</option>
            </select>
            <input
              v-if="(config.auth_type || 'none') !== 'none'"
              :value="config.auth_token || ''"
              type="password"
              placeholder="Token"
              class="mt-2 font-mono"
              :class="[INPUT_CLASS]"
              @input="updateField('auth_token', $event.target.value)"
            />
          </div>
        </template>

        <div
          v-if="
            node.type === 'send_webhook' || (config.method || 'POST') !== 'GET'
          "
        >
          <label :class="LABEL_CLASS">Corpo (JSON)</label>
          <WorkflowVariableInput
            :model-value="
              node.type === 'send_webhook' ? config.payload : config.body
            "
            multiline
            mono
            :rows="5"
            placeholder='{ "nome": "{{ $contact.name }}" }'
            @update:model-value="
              updateField(
                node.type === 'send_webhook' ? 'payload' : 'body',
                $event
              )
            "
          />
        </div>

        <template v-if="node.type === 'http_request'">
          <div class="grid grid-cols-3 gap-2">
            <div>
              <label :class="LABEL_CLASS">Timeout (s)</label>
              <input
                :value="config.timeout"
                type="number"
                min="1"
                :class="INPUT_CLASS"
                @input="
                  updateField('timeout', parseInt($event.target.value, 10) || 0)
                "
              />
            </div>
            <div>
              <label :class="LABEL_CLASS">Tentativas</label>
              <input
                :value="config.retry_count"
                type="number"
                min="0"
                :class="INPUT_CLASS"
                @input="
                  updateField(
                    'retry_count',
                    parseInt($event.target.value, 10) || 0
                  )
                "
              />
            </div>
            <div>
              <label :class="LABEL_CLASS">Intervalo (s)</label>
              <input
                :value="config.retry_interval"
                type="number"
                min="0"
                :class="INPUT_CLASS"
                @input="
                  updateField(
                    'retry_interval',
                    parseInt($event.target.value, 10) || 0
                  )
                "
              />
            </div>
          </div>
          <div>
            <label :class="LABEL_CLASS">Salvar resposta como</label>
            <input
              :value="config.save_response_as || 'http_response'"
              type="text"
              class="font-mono"
              :class="[INPUT_CLASS]"
              @input="
                updateField(
                  'save_response_as',
                  $event.target.value.replace(/[^a-zA-Z0-9_]/g, '_')
                )
              "
            />
            <p :class="HINT_CLASS">
              Use depois como
              <span class="font-mono text-n-iris-11">{{
                formatVariable(`${responseVariable}.body`)
              }}</span>
            </p>
          </div>
        </template>

        <div class="pt-1">
          <button
            type="button"
            class="w-full h-9 rounded-lg border border-n-weak text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50 flex items-center justify-center gap-2"
            :disabled="isTestingHttp || !config.url"
            @click="runHttpTest"
          >
            <span
              class="size-3.5"
              :class="
                isTestingHttp
                  ? 'i-lucide-loader-circle animate-spin'
                  : 'i-lucide-play'
              "
            />
            {{ isTestingHttp ? 'Executando…' : 'Testar requisição' }}
          </button>
          <div
            v-if="httpTestResult"
            class="mt-2 p-3 rounded-xl bg-n-alpha-1 space-y-2"
          >
            <div class="flex items-center justify-between text-xs">
              <span
                class="flex items-center gap-1 font-semibold"
                :class="
                  httpTestResult.ok
                    ? 'text-green-600 dark:text-green-400'
                    : 'text-n-ruby-11'
                "
              >
                <span
                  class="size-3.5"
                  :class="
                    httpTestResult.ok
                      ? 'i-lucide-circle-check'
                      : 'i-lucide-circle-alert'
                  "
                />
                {{ httpTestResult.statusText }}
              </span>
              <span class="text-n-slate-10">{{ httpTestResult.duration }}</span>
            </div>
            <pre
              class="max-h-48 overflow-auto p-2 rounded-lg bg-n-solid-1 text-[0.625rem] font-mono text-n-slate-12"
              >{{ JSON.stringify(httpTestResult.data, null, 2) }}</pre
            >
          </div>
          <p :class="HINT_CLASS">No teste, variáveis são enviadas vazias.</p>
        </div>
      </template>

      <template v-else-if="node.type === 'end_workflow'">
        <div>
          <label :class="LABEL_CLASS">Status final</label>
          <select
            :value="config.result_status || 'completed'"
            :class="SELECT_CLASS"
            @change="updateField('result_status', $event.target.value)"
          >
            <option value="completed">Concluído</option>
            <option value="converted">Convertido</option>
            <option value="stopped">Interrompido</option>
          </select>
        </div>
        <div>
          <label :class="LABEL_CLASS">Motivo (opcional)</label>
          <WorkflowVariableInput
            :model-value="config.reason"
            multiline
            :rows="2"
            placeholder="Por que o fluxo terminou aqui"
            @update:model-value="updateField('reason', $event)"
          />
        </div>
      </template>
    </div>

    <div v-if="!nodeMeta.isTrigger" class="p-4 border-t border-n-weak">
      <button
        type="button"
        class="w-full h-9 rounded-lg text-xs font-medium text-n-ruby-11 hover:bg-n-ruby-9/10 flex items-center justify-center gap-2 transition-colors"
        @click="emit('deleteNode', node.id)"
      >
        <span class="i-lucide-trash-2 size-3.5" />
        Excluir bloco
      </button>
    </div>
  </aside>
  <div v-else />
</template>
