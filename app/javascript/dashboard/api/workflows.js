/* global axios */

class WorkflowsAPI {
  // eslint-disable-next-line class-methods-use-this
  get baseUrl() {
    const isInsideAccountScopedURLs =
      window.location.pathname.includes('/app/accounts');
    let accountId = '';
    if (isInsideAccountScopedURLs) {
      accountId = window.location.pathname.split('/')[3];
    } else if (window.chatwootConfig?.accountId) {
      accountId = window.chatwootConfig.accountId;
    }
    return `/api/v1/accounts/${accountId}/workflows`;
  }

  // eslint-disable-next-line class-methods-use-this
  get executionsBaseUrl() {
    const isInsideAccountScopedURLs =
      window.location.pathname.includes('/app/accounts');
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

  testHttpRequest(config) {
    return axios.post(`${this.baseUrl}/test_http`, { config });
  }

  uploadMedia(file) {
    const body = new FormData();
    body.append('attachment', file);
    const accountId = this.baseUrl.split('/')[4];
    return axios.post(`/api/v1/accounts/${accountId}/upload`, body);
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

  renameWorkflow(id, name) {
    return axios.put(`${this.baseUrl}/${id}`, { workflow: { name } });
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

  getWebhookTrigger(id) {
    return axios.get(`${this.baseUrl}/${id}/webhook_trigger`);
  }

  upsertWebhookTrigger(id, attrs) {
    return axios.post(`${this.baseUrl}/${id}/webhook_trigger`, attrs);
  }

  testWebhook(id) {
    return axios.post(`${this.baseUrl}/${id}/test_webhook_trigger`);
  }

  getFlowTest(id) {
    return axios.get(`${this.baseUrl}/${id}/flow_test`);
  }

  startFlowTest(id) {
    return axios.post(`${this.baseUrl}/${id}/flow_test`);
  }

  replyFlowTest(id, payload) {
    return axios.post(`${this.baseUrl}/${id}/flow_test/reply`, payload);
  }

  timeoutFlowTest(id) {
    return axios.post(`${this.baseUrl}/${id}/flow_test/timeout`);
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

  retryExecution(id) {
    return axios.post(`${this.executionsBaseUrl}/${id}/retry`);
  }
}

export default new WorkflowsAPI();
