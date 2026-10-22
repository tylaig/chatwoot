<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();

const isWhatsAppCloud = computed(
  () =>
    props.inbox?.channel_type === 'Channel::Whatsapp' &&
    props.inbox?.provider === 'whatsapp_cloud'
);

const monthlyServiceLimitEnabled = ref(true);
const monthlyServiceLimit = ref(1000);
const monthlyServiceSafeCap = ref(990);
const allowExceedServiceLimit = ref(false);
const isSaving = ref(false);

const syncFromInbox = () => {
  const cfg = props.inbox?.provider_config || {};
  const quota = props.inbox?.monthly_service_quota || {};
  monthlyServiceLimitEnabled.value =
    cfg.monthly_service_limit_enabled !== false;
  monthlyServiceLimit.value =
    Number(cfg.monthly_service_limit || quota.limit) || 1000;
  monthlyServiceSafeCap.value =
    Number(cfg.monthly_service_safe_cap || quota.safe_cap) || 990;
  allowExceedServiceLimit.value = Boolean(
    cfg.allow_exceed_service_limit ?? quota.allow_exceed
  );
};

watch(
  () => props.inbox,
  () => syncFromInbox(),
  { immediate: true, deep: true }
);

const quota = computed(() => {
  const q = props.inbox?.monthly_service_quota || {};
  const used = Number(q.used) || 0;
  const limit = Number(q.limit || monthlyServiceLimit.value) || 1000;
  const safeCap = Number(q.safe_cap || monthlyServiceSafeCap.value) || 990;
  const allowExceed = Boolean(q.allow_exceed ?? allowExceedServiceLimit.value);
  const enabled = q.enabled ?? monthlyServiceLimitEnabled.value;
  return {
    enabled,
    used,
    limit,
    safe_cap: safeCap,
    remaining: Math.max(0, limit - used),
    safe_remaining: Math.max(0, safeCap - used),
    allow_exceed: allowExceed,
    blocked: Boolean(enabled && !allowExceed && used >= safeCap),
  };
});

const percentage = computed(() => {
  const limit = quota.value.limit || 1000;
  return Math.min(100, Math.round((quota.value.used / limit) * 100));
});

const saveQuotaConfig = async (overrides = {}) => {
  if (!props.inbox?.id || isSaving.value) return;
  isSaving.value = true;
  try {
    const nextConfig = {
      ...(props.inbox.provider_config || {}),
      monthly_service_limit_enabled: monthlyServiceLimitEnabled.value,
      monthly_service_limit: Number(monthlyServiceLimit.value) || 1000,
      monthly_service_safe_cap: Number(monthlyServiceSafeCap.value) || 990,
      allow_exceed_service_limit: Boolean(allowExceedServiceLimit.value),
      ...overrides,
    };
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      channel: {
        provider_config: nextConfig,
      },
    });
    useAlert('Configurações de franquia mensal atualizadas com sucesso.');
  } catch (err) {
    useAlert('Não foi possível salvar a configuração da franquia mensal.');
  } finally {
    isSaving.value = false;
  }
};

const toggleAllowExceed = async () => {
  allowExceedServiceLimit.value = !allowExceedServiceLimit.value;
  await saveQuotaConfig({
    allow_exceed_service_limit: allowExceedServiceLimit.value,
  });
};
</script>

<template>
  <div
    v-if="isWhatsAppCloud"
    class="flex flex-col gap-3 p-4 rounded-xl border border-n-weak bg-n-solid-1"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-col gap-0.5">
        <div class="flex items-center gap-2">
          <span class="i-lucide-shield-check size-4 text-n-brand shrink-0" />
          <span class="text-sm font-semibold text-n-slate-12">
            {{
              `Franquia Mensal Gratuita (API Oficial): ${quota.used} / ${quota.limit} respostas`
            }}
          </span>
          <span
            class="px-2 py-0.5 text-[11px] font-medium rounded-full"
            :class="
              quota.blocked
                ? 'bg-n-ruby-9/15 text-n-ruby-11'
                : quota.allow_exceed
                  ? 'bg-n-amber-9/15 text-n-amber-11'
                  : 'bg-green-500/15 text-green-600 dark:text-green-400'
            "
          >
            {{
              quota.blocked
                ? 'Bloqueado pela trava'
                : quota.allow_exceed
                  ? 'Liberado além do limite'
                  : `${quota.safe_remaining} restantes até a trava (${quota.safe_cap})`
            }}
          </span>
        </div>
        <span class="text-xs text-n-slate-11">
          {{
            'Contabiliza respostas de sessão e avisos automáticos enviados neste mês e pausa os envios antes de atingir a cobrança da Meta.'
          }}
        </span>
      </div>

      <NextButton
        size="sm"
        :variant="quota.allow_exceed ? 'faded' : 'solid'"
        :color="quota.allow_exceed ? 'amber' : 'blue'"
        :disabled="isSaving"
        :label="
          quota.allow_exceed ? 'Reativar trava do limite' : 'Usar além do limite'
        "
        @click="toggleAllowExceed"
      />
    </div>

    <div class="w-full h-2 rounded-full bg-n-alpha-2 overflow-hidden">
      <div
        class="h-full transition-all duration-300"
        :class="
          quota.blocked
            ? 'bg-n-ruby-9'
            : percentage >= 85
              ? 'bg-n-amber-9'
              : 'bg-green-500'
        "
        :style="{ width: `${percentage}%` }"
      />
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1">
          {{ 'Franquia mensal gratuita' }}
        </label>
        <woot-input
          v-model.number="monthlyServiceLimit"
          type="number"
          class="[&>input]:!mb-0"
        />
      </div>
      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1">
          {{ 'Trava de segurança (pausa envios)' }}
        </label>
        <woot-input
          v-model.number="monthlyServiceSafeCap"
          type="number"
          class="[&>input]:!mb-0"
        />
      </div>
      <div class="flex items-end">
        <NextButton
          class="w-full"
          :disabled="isSaving"
          :label="'Salvar limites'"
          @click="saveQuotaConfig()"
        />
      </div>
    </div>
  </div>
</template>
