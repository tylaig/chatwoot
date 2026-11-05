import { defineComponent, ref } from 'vue';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import ImageBubble from '../Image.vue';
import VideoBubble from '../Video.vue';
import { provideMessageContext } from '../../provider.js';
import { MESSAGE_VARIANTS, ORIENTATION } from '../../constants';

const mockLoadState = {
  isLoaded: ref(false),
  hasError: ref(false),
  loadWithRetry: vi.fn(),
};

vi.mock('dashboard/composables/loadWithRetry', () => ({
  useLoadWithRetry: () => mockLoadState,
}));

vi.mock('../Base.vue', () => ({
  default: {
    template: '<div data-test="base-bubble"><slot /></div>',
  },
}));

vi.mock('dashboard/components-next/spinner/Spinner.vue', () => ({
  default: {
    template: '<div data-test="media-spinner" />',
  },
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref([]),
}));

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  messages: {
    en: {
      COMPONENTS: {
        MEDIA: {
          IMAGE_UNAVAILABLE: 'This image is no longer available.',
          VIDEO_UNAVAILABLE: 'This video is no longer available.',
          LOADING_IMAGE: 'Loading image...',
          LOADING_VIDEO: 'Loading video...',
          OPEN_MEDIA: 'Open file',
        },
      },
    },
  },
});

const mountMediaBubble = (Component, attachmentOverrides = {}) => {
  const attachment = {
    id: 101,
    messageId: 78033,
    fileType: Component === ImageBubble ? 'image' : 'video',
    dataUrl:
      'https://inbox.gamessafari.com/rails/active_storage/blobs/media.mp4',
    fileSize: 9590000,
    ...attachmentOverrides,
  };

  const TestHost = defineComponent({
    components: { Component },
    setup() {
      provideMessageContext({
        attachments: ref([attachment]),
        variant: ref(MESSAGE_VARIANTS.USER),
        orientation: ref(ORIENTATION.LEFT),
        contentAttributes: ref({}),
        additionalAttributes: ref({}),
        shouldGroupWithNext: ref(false),
        inReplyTo: ref(null),
        id: ref(78033),
        sender: ref({}),
        senderType: ref('contact'),
        createdAt: ref(1700000000),
      });
    },
    template: '<Component />',
  });

  return mount(TestHost, {
    global: {
      plugins: [i18n],
      stubs: {
        BaseBubble: {
          template: '<div data-test="base-bubble"><slot /></div>',
        },
        GalleryView: {
          template: '<div data-test="gallery-view" />',
        },
        MessageMeta: true,
        ReferralCard: true,
        CaptainGenerationDetails: true,
        Button: true,
        Icon: true,
        Spinner: {
          template: '<div data-test="media-spinner" />',
        },
      },
    },
  });
};

describe('Media bubbles (Image & Video)', () => {
  beforeEach(() => {
    mockLoadState.isLoaded.value = false;
    mockLoadState.hasError.value = false;
    mockLoadState.loadWithRetry.mockClear();
  });

  describe('ImageBubble', () => {
    it('shows a loading spinner, file size, and direct download link while image is downloading', () => {
      const wrapper = mountMediaBubble(ImageBubble, {
        fileType: 'image',
        fileSize: 5500000,
      });

      expect(wrapper.find('[data-test="media-spinner"]').exists()).toBe(true);
      expect(wrapper.text()).toContain('Loading image...');
      expect(wrapper.text()).toContain('(5.2 MB)');
      const link = wrapper.find('a');
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe(
        'https://inbox.gamessafari.com/rails/active_storage/blobs/media.mp4'
      );
    });

    it('renders the image when loaded', () => {
      mockLoadState.isLoaded.value = true;
      const wrapper = mountMediaBubble(ImageBubble, { fileType: 'image' });

      expect(wrapper.find('[data-test="media-spinner"]').exists()).toBe(false);
      expect(wrapper.find('img').exists()).toBe(true);
      expect(wrapper.find('img').attributes('src')).toBe(
        'https://inbox.gamessafari.com/rails/active_storage/blobs/media.mp4'
      );
    });

    it('shows an error message and direct open fallback link when loading fails', () => {
      mockLoadState.hasError.value = true;
      const wrapper = mountMediaBubble(ImageBubble, {
        fileType: 'image',
        fileSize: 5500000,
      });

      expect(wrapper.text()).toContain('This image is no longer available.');
      expect(wrapper.text()).toContain('Open file');
      expect(wrapper.text()).toContain('(5.2 MB)');
      expect(wrapper.find('a').attributes('href')).toBe(
        'https://inbox.gamessafari.com/rails/active_storage/blobs/media.mp4'
      );
    });
  });

  describe('VideoBubble', () => {
    it('shows a loading spinner, file size, and direct download link while video is downloading', () => {
      const wrapper = mountMediaBubble(VideoBubble, {
        fileType: 'video',
        fileSize: 9590000,
      });

      expect(wrapper.find('[data-test="media-spinner"]').exists()).toBe(true);
      expect(wrapper.text()).toContain('Loading video...');
      expect(wrapper.text()).toContain('(9.1 MB)');
      const link = wrapper.find('a');
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe(
        'https://inbox.gamessafari.com/rails/active_storage/blobs/media.mp4'
      );
    });

    it('renders the video player when loaded', () => {
      mockLoadState.isLoaded.value = true;
      const wrapper = mountMediaBubble(VideoBubble, { fileType: 'video' });

      expect(wrapper.find('[data-test="media-spinner"]').exists()).toBe(false);
      expect(wrapper.find('video').exists()).toBe(true);
      expect(wrapper.find('video').attributes('src')).toBe(
        'https://inbox.gamessafari.com/rails/active_storage/blobs/media.mp4'
      );
    });

    it('shows an error message and direct open fallback link when video fails to load', () => {
      mockLoadState.hasError.value = true;
      const wrapper = mountMediaBubble(VideoBubble, {
        fileType: 'video',
        fileSize: 9590000,
      });

      expect(wrapper.text()).toContain('This video is no longer available.');
      expect(wrapper.text()).toContain('Open file');
      expect(wrapper.text()).toContain('(9.1 MB)');
      expect(wrapper.find('a').attributes('href')).toBe(
        'https://inbox.gamessafari.com/rails/active_storage/blobs/media.mp4'
      );
    });
  });
});
