import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import WebhookDispatchIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/webhook-dispatch'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'webhook_dispatch_index',
          component: WebhookDispatchIndex,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
