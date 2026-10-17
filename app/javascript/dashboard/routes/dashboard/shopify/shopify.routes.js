import { frontendURL } from 'dashboard/helper/URLHelper';

const ShopifyIndex = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/shopify'),
      name: 'shopify_orders_index',
      component: ShopifyIndex,
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
    },
  ],
};
