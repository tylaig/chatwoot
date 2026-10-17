/* global axios */

import ApiClient from './ApiClient';

class IntegrationsAPI extends ApiClient {
  constructor() {
    super('integrations/apps', { accountScoped: true });
  }

  connectSlack(code) {
    return axios.post(`${this.baseUrl()}/integrations/slack`, { code });
  }

  updateSlack({ referenceId, messageMode }) {
    return axios.patch(`${this.baseUrl()}/integrations/slack`, {
      reference_id: referenceId,
      message_mode: messageMode,
    });
  }

  listAllSlackChannels() {
    return axios.get(`${this.baseUrl()}/integrations/slack/list_all_channels`);
  }

  delete(integrationId) {
    return axios.delete(`${this.baseUrl()}/integrations/${integrationId}`);
  }

  createHook(hookData) {
    return axios.post(`${this.baseUrl()}/integrations/hooks`, hookData);
  }

  deleteHook(hookId) {
    return axios.delete(`${this.baseUrl()}/integrations/hooks/${hookId}`);
  }

  connectShopify({ shopDomain }) {
    return axios.post(`${this.baseUrl()}/integrations/shopify/auth`, {
      shop_domain: shopDomain,
    });
  }

  connectShopifyToken({ storeName, shopDomain, shopifyAdminKey, inboxIds }) {
    return axios.post(`${this.baseUrl()}/integrations/shopify/connect_token`, {
      store_name: storeName,
      shop_domain: shopDomain,
      access_token: shopifyAdminKey,
      inbox_ids: inboxIds,
    });
  }

  updateShopifyHook({
    hookId,
    storeName,
    shopDomain,
    shopifyAdminKey,
    inboxIds,
  }) {
    return axios.patch(`${this.baseUrl()}/integrations/shopify/update_hook`, {
      hook_id: hookId,
      store_name: storeName,
      shop_domain: shopDomain,
      access_token: shopifyAdminKey,
      inbox_ids: inboxIds,
    });
  }

  deleteShopifyHook(hookId) {
    return axios.delete(`${this.baseUrl()}/integrations/shopify`, {
      params: { hook_id: hookId },
    });
  }
}

export default new IntegrationsAPI();
