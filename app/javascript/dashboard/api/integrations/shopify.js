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
      period,
      listAll = false,
      syncContactEmail = false,
    } = params;
    return axios.get(`${this.url}/orders`, {
      params: {
        contact_id: contactId,
        query,
        inbox_id: inboxId,
        hook_id: hookId,
        period,
        list_all: listAll,
        sync_contact_email: syncContactEmail,
      },
    });
  }

  getCustomers(params = {}) {
    const { query, hookId } = params;
    return axios.get(`${this.url}/customers`, {
      params: {
        query,
        hook_id: hookId,
      },
    });
  }

  getProducts(params = {}) {
    const { query, hookId } = params;
    return axios.get(`${this.url}/products`, {
      params: {
        query,
        hook_id: hookId,
      },
    });
  }

  testConnection(hookId) {
    return axios.post(`${this.url}/test_connection`, {
      hook_id: hookId,
    });
  }

  syncProducts(hookId) {
    return axios.post(`${this.url}/sync_products`, {
      hook_id: hookId,
    });
  }
}

export default new ShopifyAPI();
