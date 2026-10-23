/* global axios */
import ApiClient from './ApiClient';

class SystemUpdatesAPI extends ApiClient {
  constructor() {
    super('system_updates', { accountScoped: true });
  }

  check(refresh = false) {
    return axios.get(`${this.url}/check`, {
      params: refresh ? { refresh: true } : {},
    });
  }

  apply({ targetSha, forceWindow = false } = {}) {
    return axios.post(`${this.url}/apply`, {
      target_sha: targetSha,
      force_window: forceWindow,
    });
  }
}

export default new SystemUpdatesAPI();
