import { frontendURL } from '../../../../helper/URLHelper';
import WebhookDispatchIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/webhook-dispatch'),
      name: 'webhook_dispatch_index',
      component: WebhookDispatchIndex,
      meta: {
        permissions: ['administrator'],
      },
    },
  ],
};
