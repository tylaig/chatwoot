<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: {
    type: Object,
    default: null,
  },
  availableTemplates: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['updateConfig', 'deleteNode', 'close']);

const cfg = computed({
  get: () => props.node?.config || {},
  set: (val) => emit('updateConfig', val),
});

const updateField = (field, value) => {
  const updated = { ...props.node.config, [field]: value };
  emit('updateConfig', updated);
};
</script>

<template>
  <div v-if="node" class="w-80 border-l border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 p-5 flex flex-col h-full overflow-y-auto select-none">
    <!-- Header -->
    <div class="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800">
      <div>
        <h3 class="text-sm font-bold text-slate-900 dark:text-white">Configurar Bloco</h3>
        <p class="text-[11px] font-mono text-slate-400">{{ node.type }}</p>
      </div>
      <button type="button" class="text-slate-400 hover:text-slate-600 text-sm p-1" @click="emit('close')">
        ✕
      </button>
    </div>

    <!-- Conteúdo Dinâmico por Tipo de Bloco -->
    <div class="py-4 space-y-4 flex-1">
      <div>
        <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">Título do Bloco</label>
        <input
          :value="node.config?.custom_title || ''"
          type="text"
          placeholder="ex: Mensagem de Boas-Vindas"
          class="w-full px-3 py-1.5 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800"
          @input="updateField('custom_title', $event.target.value)"
        />
      </div>

      <!-- WHATSAPP MESSAGE CONFIG -->
      <div v-if="node.type === 'send_whatsapp_message' || node.type === 'send_message'" class="space-y-4">
        <!-- SELEÇÃO CRÍTICA DA JANELA DE 24H -->
        <div>
          <label class="block text-xs font-bold text-slate-900 dark:text-white mb-2">
            Contexto da Janela de 24h *
          </label>
          <div class="space-y-2">
            <label class="flex items-start gap-2.5 p-2.5 rounded-xl border cursor-pointer transition-colors" :class="node.config?.delivery_mode === 'inside_24h' ? 'border-primary-500 bg-primary-50/20' : 'border-slate-200 dark:border-slate-800'">
              <input
                type="radio"
                name="delivery_mode"
                value="inside_24h"
                :checked="node.config?.delivery_mode === 'inside_24h'"
                class="mt-0.5 text-primary-600"
                @change="updateField('delivery_mode', 'inside_24h')"
              />
              <div>
                <p class="text-xs font-semibold text-slate-800 dark:text-slate-200">Dentro da janela de 24h</p>
                <p class="text-[10px] text-slate-500">Permite texto livre e mídias diretas enquanto o cliente estiver ativo.</p>
              </div>
            </label>

            <label class="flex items-start gap-2.5 p-2.5 rounded-xl border cursor-pointer transition-colors" :class="node.config?.delivery_mode === 'outside_24h' ? 'border-primary-500 bg-primary-50/20' : 'border-slate-200 dark:border-slate-800'">
              <input
                type="radio"
                name="delivery_mode"
                value="outside_24h"
                :checked="node.config?.delivery_mode === 'outside_24h'"
                class="mt-0.5 text-primary-600"
                @change="updateField('delivery_mode', 'outside_24h')"
              />
              <div>
                <p class="text-xs font-semibold text-slate-800 dark:text-slate-200">Fora da janela de 24h</p>
                <p class="text-[10px] text-slate-500">Exige obrigatoriamente um Template oficial aprovado pela Meta.</p>
              </div>
            </label>

            <label class="flex items-start gap-2.5 p-2.5 rounded-xl border cursor-pointer transition-colors" :class="(!node.config?.delivery_mode || node.config?.delivery_mode === 'auto') ? 'border-primary-500 bg-primary-50/20' : 'border-slate-200 dark:border-slate-800'">
              <input
                type="radio"
                name="delivery_mode"
                value="auto"
                :checked="!node.config?.delivery_mode || node.config?.delivery_mode === 'auto'"
                class="mt-0.5 text-primary-600"
                @change="updateField('delivery_mode', 'auto')"
              />
              <div>
                <p class="text-xs font-semibold text-slate-800 dark:text-slate-200">Automático (Detectar na Execução)</p>
                <p class="text-[10px] text-slate-500">Envia texto livre se a janela estiver aberta ou chaveia para template se expirada.</p>
              </div>
            </label>
          </div>
        </div>

        <!-- Texto Livre (se dentro ou auto) -->
        <div v-if="node.config?.delivery_mode !== 'outside_24h'">
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
            Mensagem de Texto Livre
          </label>
          <textarea
            :value="node.config?.text || ''"
            rows="4"
            placeholder="Olá {{contact.first_name}}, podemos continuar?"
            class="w-full p-2.5 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 leading-relaxed"
            @input="updateField('text', $event.target.value)"
          />
          <p class="text-[10px] text-slate-400 mt-1">Dica: use variáveis como <code class="text-primary-600 font-mono">&#123;&#123;contact.first_name&#125;&#125;</code></p>
        </div>

        <!-- Template Aprovado (se fora ou auto) -->
        <div v-if="node.config?.delivery_mode === 'outside_24h' || node.config?.delivery_mode === 'auto'">
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
            Template Aprovado WhatsApp *
          </label>
          <select
            :value="node.config?.template_name || ''"
            class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-800 dark:text-white"
            @change="updateField('template_name', $event.target.value)"
          >
            <option value="">Selecione um template aprovado...</option>
            <option v-for="tpl in availableTemplates" :key="tpl.id" :value="tpl.name">
              {{ tpl.name }} ({{ tpl.category }})
            </option>
          </select>
        </div>
      </div>

      <!-- CONDITION CONFIG -->
      <div v-else-if="node.type === 'condition'" class="space-y-3">
        <p class="text-xs font-bold text-slate-800 dark:text-slate-200">Regras de Validação (IF)</p>
        <div class="p-3 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/40 space-y-2">
          <div>
            <label class="block text-[11px] font-semibold text-slate-600 mb-0.5">Campo / Variável</label>
            <input
              :value="node.config?.conditions?.[0]?.field || 'webhook.status'"
              type="text"
              placeholder="ex: webhook.status ou contact.phone"
              class="w-full px-2.5 py-1 text-xs rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 font-mono"
              @input="updateField('conditions', [{ field: $event.target.value, operator: node.config?.conditions?.[0]?.operator || 'equal_to', value: node.config?.conditions?.[0]?.value || '' }])"
            />
          </div>

          <div>
            <label class="block text-[11px] font-semibold text-slate-600 mb-0.5">Operador</label>
            <select
              :value="node.config?.conditions?.[0]?.operator || 'equal_to'"
              class="w-full px-2.5 py-1 text-xs rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900"
              @change="updateField('conditions', [{ field: node.config?.conditions?.[0]?.field || '', operator: $event.target.value, value: node.config?.conditions?.[0]?.value || '' }])"
            >
              <option value="equal_to">É igual a (==)</option>
              <option value="not_equal_to">É diferente (!=)</option>
              <option value="contains">Contém</option>
              <option value="is_empty">Está vazio</option>
            </select>
          </div>

          <div>
            <label class="block text-[11px] font-semibold text-slate-600 mb-0.5">Valor Esperado</label>
            <input
              :value="node.config?.conditions?.[0]?.value || ''"
              type="text"
              placeholder="ex: interested"
              class="w-full px-2.5 py-1 text-xs rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900"
              @input="updateField('conditions', [{ field: node.config?.conditions?.[0]?.field || '', operator: node.config?.conditions?.[0]?.operator || 'equal_to', value: $event.target.value }])"
            />
          </div>
        </div>
      </div>

      <!-- DELAY CONFIG -->
      <div v-else-if="node.type === 'delay'" class="space-y-3">
        <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300">Duração da Espera</label>
        <div class="flex items-center gap-2">
          <input
            :value="node.config?.duration || 10"
            type="number"
            min="1"
            class="w-24 px-3 py-1.5 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800"
            @input="updateField('duration', $event.target.value)"
          />
          <select
            :value="node.config?.unit || 'minutes'"
            class="flex-1 px-3 py-1.5 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800"
            @change="updateField('unit', $event.target.value)"
          >
            <option value="seconds">Segundos</option>
            <option value="minutes">Minutos</option>
            <option value="hours">Horas</option>
            <option value="days">Dias</option>
          </select>
        </div>
      </div>

      <!-- WAIT FOR REPLY CONFIG -->
      <div v-else-if="node.type === 'wait_for_reply'" class="space-y-3">
        <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300">Tempo Limite (Timeout)</label>
        <div class="flex items-center gap-2">
          <input
            :value="node.config?.timeout_hours || 24"
            type="number"
            min="1"
            class="w-24 px-3 py-1.5 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800"
            @input="updateField('timeout_hours', $event.target.value)"
          />
          <span class="text-xs text-slate-500">horas até expirar</span>
        </div>
      </div>

      <!-- ADD TAG CONFIG -->
      <div v-else-if="node.type === 'add_tag'" class="space-y-3">
        <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300">Nome da Tag / Label</label>
        <input
          :value="node.config?.tag_name || ''"
          type="text"
          placeholder="ex: follow_up_pending"
          class="w-full px-3 py-1.5 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800"
          @input="updateField('tag_name', $event.target.value)"
        />
      </div>
    </div>

    <!-- Footer Action -->
    <div class="pt-4 border-t border-slate-100 dark:border-slate-800">
      <button
        v-if="node.type !== 'webhook_trigger'"
        type="button"
        class="w-full py-2 px-3 rounded-xl border border-rose-200 dark:border-rose-900 text-rose-600 dark:text-rose-400 text-xs font-semibold hover:bg-rose-50 dark:hover:bg-rose-950 transition-colors"
        @click="emit('deleteNode', node.id)"
      >
        Excluir Bloco
      </button>
    </div>
  </div>
</template>
