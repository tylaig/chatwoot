import { frontendURL } from 'dashboard/helper/URLHelper';

const WorkflowsIndex = () => import('./Index.vue');
const WorkflowBuilder = () => import('./Builder.vue');
const WorkflowExecutions = () => import('./Executions.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/workflows'),
      name: 'workflows_index',
      component: WorkflowsIndex,
      roles: ['administrator', 'agent'],
    },
    {
      path: frontendURL('accounts/:accountId/workflows/:workflowId/builder'),
      name: 'workflow_builder',
      component: WorkflowBuilder,
      roles: ['administrator', 'agent'],
    },
    {
      path: frontendURL('accounts/:accountId/workflows/:workflowId/executions'),
      name: 'workflow_executions',
      component: WorkflowExecutions,
      roles: ['administrator', 'agent'],
    },
  ],
};
