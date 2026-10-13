/* global axios */

const accountId = () => {
  if (window.location.pathname.includes('/app/accounts')) {
    return window.location.pathname.split('/')[3];
  }
  return window.chatwootConfig?.accountId || '';
};

const root = () => `/api/v1/accounts/${accountId()}`;

export default {
  getConnection() {
    return axios.get(`${root()}/evolution_connection`);
  },
  saveConnection(payload) {
    return axios.put(`${root()}/evolution_connection`, payload);
  },
  syncConnection() {
    return axios.post(`${root()}/evolution_connection/check`);
  },
  getInstances() {
    return axios.get(`${root()}/evolution_instances`);
  },
  createInstance(payload) {
    return axios.post(`${root()}/evolution_instances`, payload);
  },
  deleteInstance(name) {
    return axios.delete(
      `${root()}/evolution_instances/${encodeURIComponent(name)}`
    );
  },
  connectInstance(name) {
    return axios.get(
      `${root()}/evolution_instances/${encodeURIComponent(name)}/connect`
    );
  },
  connectionState(name) {
    return axios.get(
      `${root()}/evolution_instances/${encodeURIComponent(name)}/connection_state`
    );
  },
  logoutInstance(name) {
    return axios.delete(
      `${root()}/evolution_instances/${encodeURIComponent(name)}/logout`
    );
  },
  restartInstance(name) {
    return axios.put(
      `${root()}/evolution_instances/${encodeURIComponent(name)}/restart`
    );
  },
  getWebhook(name) {
    return axios.get(
      `${root()}/evolution_instances/${encodeURIComponent(name)}/webhook`
    );
  },
  saveWebhook(name, payload) {
    return axios.post(
      `${root()}/evolution_instances/${encodeURIComponent(name)}/webhook`,
      payload
    );
  },
};
