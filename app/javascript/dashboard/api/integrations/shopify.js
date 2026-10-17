/* global axios */

import ApiClient from '../ApiClient';

class ShopifyAPI extends ApiClient {
  constructor() {
    super('integrations/shopify', { accountScoped: true });
  }

  getOrders(params = {}) {
    if (typeof params === 'number' || typeof params === 'string') {
      return axios.get(`${this.url}/orders`, {
        params: { contact_id: params },
      });
    }
    const {
      contactId,
      query,
      inboxId,
      hookId,
      syncContactEmail = false,
    } = params;
    return axios.get(`${this.url}/orders`, {
      params: {
        contact_id: contactId,
        query,
        inbox_id: inboxId,
        hook_id: hookId,
        sync_contact_email: syncContactEmail,
      },
    });
  }
}

export default new ShopifyAPI();
