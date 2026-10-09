import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Index from './Index.vue';
import NewTemplateView from './NewTemplateView.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/templates'),
      children: [
        {
          path: '',
          name: 'whatsapp_templates_index',
          component: Index,
          meta: {
            permissions: ['administrator', 'agent'],
          },
        },
        {
          path: 'new',
          name: 'whatsapp_templates_new',
          component: NewTemplateView,
          meta: {
            permissions: ['administrator', 'agent'],
          },
        },
      ],
    },
  ],
};
