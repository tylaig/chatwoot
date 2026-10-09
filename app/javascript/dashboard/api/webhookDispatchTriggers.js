/* global axios */

const getAccountId = () => {
  const isInsideAccountScopedURLs =
    window.location.pathname.includes('/app/accounts');
  if (isInsideAccountScopedURLs) {
    return window.location.pathname.split('/')[3];
  }
  return window.chatwootConfig?.accountId || '';
};

export default {
  getTriggers() {
    return axios.get(
      `/api/v1/accounts/${getAccountId()}/webhook_dispatch_triggers`
    );
  },
  getTrigger(id) {
    return axios.get(
      `/api/v1/accounts/${getAccountId()}/webhook_dispatch_triggers/${id}`
    );
  },
  createTrigger(data) {
    return axios.post(
      `/api/v1/accounts/${getAccountId()}/webhook_dispatch_triggers`,
      {
        webhook_dispatch_trigger: data,
      }
    );
  },
  updateTrigger(id, data) {
    return axios.put(
      `/api/v1/accounts/${getAccountId()}/webhook_dispatch_triggers/${id}`,
      {
        webhook_dispatch_trigger: data,
      }
    );
  },
  deleteTrigger(id) {
    return axios.delete(
      `/api/v1/accounts/${getAccountId()}/webhook_dispatch_triggers/${id}`
    );
  },
  testPayload(id, payload) {
    return axios.post(
      `/api/v1/accounts/${getAccountId()}/webhook_dispatch_triggers/${id}/test_payload`,
      {
        payload,
      }
    );
  },
};
