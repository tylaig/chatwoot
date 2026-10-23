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

  connectShopifyToken({
    storeName,
    shopDomain,
    shopifyAdminKey,
    inboxIds,
    agentIds,
  }) {
    return axios.post(`${this.baseUrl()}/integrations/shopify/connect_token`, {
      store_name: storeName,
      shop_domain: shopDomain,
      access_token: shopifyAdminKey,
      inbox_ids: inboxIds,
      agent_ids: agentIds,
    });
  }

  updateShopifyHook({
    hookId,
    storeName,
    shopDomain,
    shopifyAdminKey,
    inboxIds,
    agentIds,
  }) {
    return axios.patch(`${this.baseUrl()}/integrations/shopify/update_hook`, {
      hook_id: hookId,
      store_name: storeName,
      shop_domain: shopDomain,
      access_token: shopifyAdminKey,
      inbox_ids: inboxIds,
      agent_ids: agentIds,
    });
  }

  testShopifyConnection(hookId) {
    return axios.post(
      `${this.baseUrl()}/integrations/shopify/test_connection`,
      {
        hook_id: hookId,
      }
    );
  }

  syncShopifyProducts(hookId) {
    return axios.post(`${this.baseUrl()}/integrations/shopify/sync_products`, {
      hook_id: hookId,
    });
  }

  deleteShopifyHook(hookId) {
    return axios.delete(`${this.baseUrl()}/integrations/shopify`, {
      params: { hook_id: hookId },
    });
  }

  getGoogleCalendarIntegrations() {
    return axios.get(`${this.baseUrl()}/integrations/google_calendar`);
  }

  saveGoogleCalendarOauthCredentials({ clientId, clientSecret }) {
    return axios.post(
      `${this.baseUrl()}/integrations/google_calendar/save_oauth_credentials`,
      {
        client_id: clientId,
        client_secret: clientSecret,
      }
    );
  }

  startGoogleCalendarOauth({ hookId, scheduleId, returnTo = 'integrations' }) {
    return axios.post(`${this.baseUrl()}/integrations/google_calendar/auth`, {
      hook_id: hookId,
      schedule_id: scheduleId,
      return_to: returnTo,
    });
  }

  connectGoogleCalendarHook(payload) {
    return axios.post(
      `${this.baseUrl()}/integrations/google_calendar/connect`,
      payload
    );
  }

  updateGoogleCalendarHook(payload) {
    return axios.patch(
      `${this.baseUrl()}/integrations/google_calendar/update_hook`,
      payload
    );
  }

  testGoogleCalendarConnection(hookId) {
    return axios.post(
      `${this.baseUrl()}/integrations/google_calendar/test_connection`,
      {
        hook_id: hookId,
      }
    );
  }

  syncGoogleCalendarEvents(hookId) {
    return axios.post(
      `${this.baseUrl()}/integrations/google_calendar/sync_events`,
      {
        hook_id: hookId,
      }
    );
  }

  deleteGoogleCalendarHook(hookId, disconnectSchedules = false) {
    return axios.delete(`${this.baseUrl()}/integrations/google_calendar`, {
      params: {
        hook_id: hookId,
        disconnect_schedules: disconnectSchedules ? 1 : undefined,
      },
    });
  }
}

export default new IntegrationsAPI();
