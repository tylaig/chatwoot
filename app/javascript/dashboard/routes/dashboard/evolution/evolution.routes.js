import { frontendURL } from 'dashboard/helper/URLHelper';

const EvolutionIndex = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/evolution'),
      name: 'evolution_index',
      component: EvolutionIndex,
      meta: {
        permissions: ['administrator'],
      },
    },
  ],
};
