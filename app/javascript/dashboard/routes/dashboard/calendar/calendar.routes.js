import { frontendURL } from 'dashboard/helper/URLHelper';

const CalendarIndex = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/agendamentos'),
      name: 'calendar_schedules_index',
      component: CalendarIndex,
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
    },
  ],
};
