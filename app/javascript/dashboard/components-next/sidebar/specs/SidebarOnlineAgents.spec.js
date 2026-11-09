import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import SidebarOnlineAgents from '../SidebarOnlineAgents.vue';

const mockAgents = ref([]);
const mockCurrentUser = ref({
  id: 11,
  accounts: [{ id: 1, availability_status: 'online' }],
});
const mockAccountId = ref(1);
const mockIsAdmin = ref(false);
const mockDispatch = vi.fn(() => Promise.resolve());

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => {
    if (key === 'agents/getAgents') return mockAgents;
    if (key === 'getCurrentUser') return mockCurrentUser;
    if (key === 'getCurrentAccountId') return mockAccountId;
    return ref(null);
  },
  useStore: () => ({
    dispatch: mockDispatch,
  }),
}));

vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({
    isAdmin: mockIsAdmin,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => {
      if (key === 'SIDEBAR.ONLINE_AGENTS.TITLE') {
        return `ATENDENTES CONECTADOS (${params?.count ?? 0})`;
      }
      if (key === 'SIDEBAR.ONLINE_AGENTS.OFFLINE_AGENTS') {
        return `Offline (${params?.count ?? 0})`;
      }
      if (key === 'SIDEBAR.ONLINE_AGENTS.STATUS.ONLINE') return 'Online';
      if (key === 'SIDEBAR.ONLINE_AGENTS.STATUS.BUSY') return 'Ocupado';
      if (key === 'SIDEBAR.ONLINE_AGENTS.STATUS.OFFLINE') return 'Offline';
      if (key === 'SIDEBAR.ONLINE_AGENTS.EMPTY') {
        return 'Nenhum atendente conectado no momento';
      }
      return key;
    },
  }),
}));

const mountComponent = (props = {}) =>
  mount(SidebarOnlineAgents, {
    props,
    global: {
      stubs: {
        Avatar: {
          props: ['name', 'status'],
          template:
            '<div data-test-id="agent-avatar" :data-status="status">{{ name }}</div>',
        },
        Icon: true,
      },
    },
  });

describe('SidebarOnlineAgents', () => {
  beforeEach(() => {
    mockIsAdmin.value = false;
    mockDispatch.mockClear();
    mockAgents.value = [
      {
        id: 1,
        name: 'Bruna Souza',
        available_name: 'Bruna Souza',
        availability_status: 'online',
      },
      {
        id: 2,
        name: 'Lucas Pereira',
        available_name: 'Lucas Pereira',
        availability_status: 'busy',
      },
      {
        id: 3,
        name: 'Nathan Offline',
        available_name: 'Nathan Offline',
        availability_status: 'offline',
      },
    ];
  });

  it('renders only online and busy agents and omits offline agents', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('ATENDENTES CONECTADOS (2)');
    expect(wrapper.text()).toContain('Bruna Souza');
    expect(wrapper.text()).toContain('Online');
    expect(wrapper.text()).toContain('Lucas Pereira');
    expect(wrapper.text()).toContain('Ocupado');
    expect(wrapper.text()).not.toContain('Nathan Offline');
    expect(wrapper.find('[data-test-id="set-offline-1"]').exists()).toBe(false);
  });

  it('shows empty state message when all agents are offline', () => {
    mockAgents.value = [
      {
        id: 3,
        name: 'Nathan Offline',
        available_name: 'Nathan Offline',
        availability_status: 'offline',
      },
    ];

    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('ATENDENTES CONECTADOS (0)');
    expect(wrapper.text()).toContain('Nenhum atendente conectado no momento');
    expect(wrapper.text()).not.toContain('Nathan Offline');
  });

  it('renders compact badge when sidebar is collapsed', () => {
    const wrapper = mountComponent({ isCollapsed: true });

    expect(wrapper.text()).toBe('2');
  });

  it('allows administrators to set online agents offline and offline agents online', async () => {
    mockIsAdmin.value = true;
    const wrapper = mountComponent();

    const setOfflineBtn = wrapper.find('[data-test-id="set-offline-1"]');
    expect(setOfflineBtn.exists()).toBe(true);

    await setOfflineBtn.trigger('click');
    expect(mockDispatch).toHaveBeenCalledWith('agents/update', {
      id: 1,
      availability: 'offline',
      auto_offline: false,
    });

    const manageTeamBtn = wrapper.find(
      'button[title="SIDEBAR.ONLINE_AGENTS.MANAGE_TEAM"]'
    );
    await manageTeamBtn.trigger('click');

    expect(wrapper.text()).toContain('Offline (1)');
    expect(wrapper.text()).toContain('Nathan Offline');

    const setOnlineBtn = wrapper.find('[data-test-id="set-online-3"]');
    expect(setOnlineBtn.exists()).toBe(true);
    await setOnlineBtn.trigger('click');
    expect(mockDispatch).toHaveBeenCalledWith('agents/update', {
      id: 3,
      availability: 'online',
      auto_offline: false,
    });
  });
});
