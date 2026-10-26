import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import UnavailableAssigneeRedistributionToggles from '../UnavailableAssigneeRedistributionToggles.vue';

const mockDispatch = vi.fn();
vi.mock('vuex', () => ({ useStore: () => ({ dispatch: mockDispatch }) }));

vi.mock('vue-i18n', async () => {
  const actual = await vi.importActual('vue-i18n');
  return { ...actual, useI18n: () => ({ t: key => key }) };
});

const mockAlert = vi.fn();
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => mockAlert(...args),
}));

const mountToggles = inbox =>
  mount(UnavailableAssigneeRedistributionToggles, {
    props: { inbox },
    global: { mocks: { $t: key => key } },
  });

const switches = wrapper => wrapper.findAll('button[role="switch"]');

describe('UnavailableAssigneeRedistributionToggles', () => {
  beforeEach(() => vi.clearAllMocks());

  it('defaults all four toggles to true when enable_auto_assignment is true and flags are unset', () => {
    const wrapper = mountToggles({
      id: 41,
      enable_auto_assignment: true,
    });

    const toggles = switches(wrapper);
    expect(toggles).toHaveLength(4);
    toggles.forEach(toggle => {
      expect(toggle.attributes('aria-checked')).toBe('true');
    });
  });

  it('respects individual saved boolean settings', () => {
    const wrapper = mountToggles({
      id: 41,
      enable_auto_assignment: true,
      unassign_on_reopen_when_offline: true,
      unassign_on_reopen_when_busy: false,
      redistribute_open_on_reply_when_offline: true,
      redistribute_open_on_reply_when_busy: false,
    });

    const toggles = switches(wrapper);
    expect(toggles[0].attributes('aria-checked')).toBe('true');
    expect(toggles[1].attributes('aria-checked')).toBe('false');
    expect(toggles[2].attributes('aria-checked')).toBe('true');
    expect(toggles[3].attributes('aria-checked')).toBe('false');
  });

  it('dispatches updateInbox when toggling a setting', async () => {
    const wrapper = mountToggles({
      id: 41,
      enable_auto_assignment: true,
      unassign_on_reopen_when_busy: true,
    });

    const toggles = switches(wrapper);
    await toggles[1].trigger('click');
    await flushPromises();

    expect(mockDispatch).toHaveBeenCalledWith('inboxes/updateInbox', {
      id: 41,
      formData: false,
      unassign_on_reopen_when_busy: false,
    });
    expect(mockAlert).toHaveBeenCalledWith(
      'INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'
    );
  });

  it('reverts toggle state if API call fails', async () => {
    mockDispatch.mockRejectedValueOnce(new Error('422'));
    const wrapper = mountToggles({
      id: 41,
      enable_auto_assignment: true,
      redistribute_open_on_reply_when_busy: true,
    });

    const toggles = switches(wrapper);
    await toggles[3].trigger('click');
    await flushPromises();

    expect(toggles[3].attributes('aria-checked')).toBe('true');
    expect(mockAlert).toHaveBeenCalledWith('INBOX_MGMT.EDIT.API.ERROR_MESSAGE');
  });
});
