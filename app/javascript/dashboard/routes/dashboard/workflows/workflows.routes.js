import { frontendURL } from 'dashboard/helper/URLHelper';

const WorkflowsIndex = () => import('./Index.vue');
const WorkflowBuilder = () => import('./Builder.vue');
const WorkflowExecutions = () => import('./Executions.vue');
const WorkflowExecutionDetail = () => import('./ExecutionDetail.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/workflows'),
      name: 'workflows_index',
      component: WorkflowsIndex,
      meta: {
        permissions: ['administrator', 'agent'],
      },
    },
    {
      path: frontendURL('accounts/:accountId/workflows/:workflowId/builder'),
      name: 'workflow_builder',
      component: WorkflowBuilder,
      meta: {
        permissions: ['administrator', 'agent'],
      },
    },
    {
      path: frontendURL('accounts/:accountId/workflows/:workflowId/executions'),
      name: 'workflow_executions',
      component: WorkflowExecutions,
      meta: {
        permissions: ['administrator', 'agent'],
      },
    },
    {
      path: frontendURL(
        'accounts/:accountId/workflows/:workflowId/executions/:executionId'
      ),
      name: 'workflow_execution_detail',
      component: WorkflowExecutionDetail,
      meta: {
        permissions: ['administrator', 'agent'],
      },
    },
  ],
};
