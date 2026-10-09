/* global axios */

class WhatsappTemplatesAPI {
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
    return `/api/v1/accounts/${accountId}/whatsapp_templates`;
  }

  getTemplates() {
    return axios.get(this.baseUrl);
  }

  getTemplate(id) {
    return axios.get(`${this.baseUrl}/${id}`);
  }

  createTemplate(data) {
    return axios.post(this.baseUrl, {
      whatsapp_template: data,
    });
  }

  updateTemplate(id, data) {
    return axios.put(`${this.baseUrl}/${id}`, {
      whatsapp_template: data,
    });
  }

  deleteTemplate(id) {
    return axios.delete(`${this.baseUrl}/${id}`);
  }

  approveTemplate(id) {
    return axios.post(`${this.baseUrl}/${id}/approve`);
  }

  submitReview(id) {
    return axios.post(`${this.baseUrl}/${id}/submit_review`);
  }

  rejectTemplate(id, reason) {
    return axios.post(`${this.baseUrl}/${id}/reject`, { reason });
  }
}

export default new WhatsappTemplatesAPI();
