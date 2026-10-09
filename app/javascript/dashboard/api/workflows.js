import axios from 'axios';

class WorkflowsAPI {
  get baseUrl() {
    const isInsideAccountScopedURLs = window.location.pathname.includes('/app/accounts');
    let accountId = '';
    if (isInsideAccountScopedURLs) {
      accountId = window.location.pathname.split('/')[3];
    } else if (window.chatwootConfig?.accountId) {
      accountId = window.chatwootConfig.accountId;
    }
    return `/api/v1/accounts/${accountId}/workflows`;
  }

  get executionsBaseUrl() {
    const isInsideAccountScopedURLs = window.location.pathname.includes('/app/accounts');
    let accountId = '';
    if (isInsideAccountScopedURLs) {
      accountId = window.location.pathname.split('/')[3];
    } else if (window.chatwootConfig?.accountId) {
      accountId = window.chatwootConfig.accountId;
    }
    return `/api/v1/accounts/${accountId}/workflow_executions`;
  }

  getWorkflows(params = {}) {
    return axios.get(this.baseUrl, { params });
  }

  getWorkflow(id) {
    return axios.get(`${this.baseUrl}/${id}`);
  }

  createWorkflow(data) {
    return axios.post(this.baseUrl, { workflow: data });
  }

  updateWorkflow(id, data, draftVersion = null) {
    return axios.put(`${this.baseUrl}/${id}`, {
      workflow: data,
      draft_version: draftVersion,
    });
  }

  deleteWorkflow(id) {
    return axios.delete(`${this.baseUrl}/${id}`);
  }

  publishWorkflow(id, summary = '') {
    return axios.post(`${this.baseUrl}/${id}/publish`, { summary });
  }

  pauseWorkflow(id) {
    return axios.post(`${this.baseUrl}/${id}/pause`);
  }

  activateWorkflow(id) {
    return axios.post(`${this.baseUrl}/${id}/activate`);
  }

  duplicateWorkflow(id) {
    return axios.post(`${this.baseUrl}/${id}/duplicate`);
  }

  getWorkflowExecutions(id) {
    return axios.get(`${this.baseUrl}/${id}/executions`);
  }

  getExecutions(params = {}) {
    return axios.get(this.executionsBaseUrl, { params });
  }

  getExecution(id) {
    return axios.get(`${this.executionsBaseUrl}/${id}`);
  }

  cancelExecution(id) {
    return axios.post(`${this.executionsBaseUrl}/${id}/cancel`);
  }
}

export default new WorkflowsAPI();
