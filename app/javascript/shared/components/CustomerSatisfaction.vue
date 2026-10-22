<script>
import { mapGetters } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import { CSAT_RATINGS, CSAT_DISPLAY_TYPES } from 'shared/constants/messages';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import StarRating from 'shared/components/StarRating.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getContrastingTextColor } from '@chatwoot/utils';

export default {
  components: {
    Spinner,
    FluentIcon,
    StarRating,
  },
  props: {
    messageContentAttributes: {
      type: Object,
      default: () => {},
    },
    messageId: {
      type: Number,
      required: true,
    },
    displayType: {
      type: String,
      default: CSAT_DISPLAY_TYPES.EMOJI,
    },
    googleReviewUrl: {
      type: String,
      default: '',
    },
    message: {
      type: String,
      default: '',
    },
  },
  setup() {
    const { formatMessage } = useMessageFormatter();
    return { formatMessage };
  },
  data() {
    return {
      email: '',
      ratings: CSAT_RATINGS,
      selectedRating: null,
      isUpdating: false,
      feedback: '',
    };
  },
  computed: {
    ...mapGetters({ widgetColor: 'appConfig/getWidgetColor' }),
    isRatingSubmitted() {
      return this.messageContentAttributes?.csat_survey_response?.rating;
    },
    isFeedbackSubmitted() {
      return this.messageContentAttributes?.csat_survey_response
        ?.feedback_message;
    },
    hasGoogleReviewUrl() {
      return Boolean(this.googleReviewUrl?.trim());
    },
    isHighRating() {
      return Number(this.selectedRating) >= 4;
    },
    isLowRating() {
      return (
        Number(this.selectedRating) >= 1 && Number(this.selectedRating) <= 3
      );
    },
    shouldShowGoogleReviewPrompt() {
      return this.hasGoogleReviewUrl && this.isHighRating;
    },
    shouldShowFeedbackForm() {
      if (this.isFeedbackSubmitted) return false;
      if (this.hasGoogleReviewUrl) {
        return this.isLowRating;
      }
      return true;
    },
    feedbackPlaceholder() {
      return this.hasGoogleReviewUrl && this.isLowRating
        ? this.$t('CSAT.LOW_RATING_PLACEHOLDER')
        : this.$t('CSAT.PLACEHOLDER');
    },
    isButtonDisabled() {
      if (!(this.selectedRating && this.feedback)) return true;
      if (this.isUpdating) return true;
      return false;
    },
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    title() {
      if (this.isRatingSubmitted && this.shouldShowGoogleReviewPrompt) {
        return this.$t('CSAT.HIGH_RATING_TITLE');
      }
      if (
        this.isRatingSubmitted &&
        this.hasGoogleReviewUrl &&
        this.isLowRating &&
        !this.isFeedbackSubmitted
      ) {
        return this.$t('CSAT.LOW_RATING_TITLE');
      }
      return this.isRatingSubmitted
        ? this.$t('CSAT.SUBMITTED_TITLE')
        : this.message || this.$t('CSAT.TITLE');
    },
    formattedTitle() {
      return this.formatMessage(this.title, false);
    },
    isEmojiType() {
      return this.displayType === CSAT_DISPLAY_TYPES.EMOJI;
    },
    isStarType() {
      return this.displayType === CSAT_DISPLAY_TYPES.STAR;
    },
  },

  mounted() {
    if (this.isRatingSubmitted) {
      const {
        csat_survey_response: { rating, feedback_message },
      } = this.messageContentAttributes;
      this.selectedRating = rating;
      this.feedback = feedback_message;
    }
  },

  methods: {
    buttonClass(rating) {
      const isLocked = this.isFeedbackSubmitted || this.isUpdating;
      return [
        { selected: rating.value === this.selectedRating },
        { disabled: isLocked },
        { hover: isLocked },
        'emoji-button',
      ];
    },
    openGoogleReview() {
      if (!this.hasGoogleReviewUrl) return;
      window.open(this.googleReviewUrl.trim(), '_blank', 'noopener,noreferrer');
    },
    async onSubmit() {
      if (this.isUpdating) return;
      this.isUpdating = true;
      try {
        await this.$store.dispatch('message/update', {
          submittedValues: {
            csat_survey_response: {
              rating: this.selectedRating,
              feedback_message: this.feedback,
            },
          },
          messageId: this.messageId,
        });
      } catch (error) {
        // Ignore error
      } finally {
        this.isUpdating = false;
      }
    },

    selectRating(rating) {
      if (this.isFeedbackSubmitted || this.isUpdating) return;
      this.selectedRating = rating.value;
      if (this.hasGoogleReviewUrl && Number(rating.value) >= 4) {
        this.openGoogleReview();
      }
      this.onSubmit();
    },
    selectStarRating(value) {
      if (this.isFeedbackSubmitted || this.isUpdating) return;
      this.selectedRating = value;
      if (this.hasGoogleReviewUrl && Number(value) >= 4) {
        this.openGoogleReview();
      }
      this.onSubmit();
    },
  },
};
</script>

<template>
  <div
    class="customer-satisfaction w-full bg-n-background dark:bg-n-solid-3 shadow-[0_0.25rem_6px_rgba(50,50,93,0.08),0_1px_3px_rgba(0,0,0,0.05)] ltr:rounded-bl-[0.25rem] rtl:rounded-br-[0.25rem] rounded-lg inline-block leading-[1.5] mt-1 border-t-2 border-t-n-brand border-solid"
    :style="{ borderColor: widgetColor }"
  >
    <h6
      v-dompurify-html="formattedTitle"
      class="text-n-slate-12 text-sm font-medium pt-5 px-2.5 text-center prose prose-bubble"
    />
    <div v-if="isEmojiType" class="ratings flex justify-around py-5 px-4">
      <button
        v-for="rating in ratings"
        :key="rating.key"
        :class="buttonClass(rating)"
        @click="selectRating(rating)"
      >
        {{ rating.emoji }}
      </button>
    </div>
    <StarRating
      v-else-if="isStarType"
      :selected-rating="selectedRating"
      :is-disabled="isFeedbackSubmitted || isUpdating"
      @select-rating="selectStarRating"
    />
    <div
      v-if="shouldShowGoogleReviewPrompt"
      class="px-4 pb-4 flex flex-col items-center gap-2 text-center"
    >
      <a
        :href="googleReviewUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="w-full py-2 px-3 rounded-lg text-xs font-semibold inline-flex items-center justify-center gap-1.5 transition-opacity hover:opacity-90 no-underline"
        :style="{
          background: widgetColor,
          color: textColor,
        }"
      >
        <span>{{ $t('CSAT.GOOGLE_REVIEW_CTA') }}</span>
      </a>
    </div>
    <form
      v-if="shouldShowFeedbackForm"
      class="feedback-form flex"
      @submit.prevent="onSubmit()"
    >
      <input
        v-model="feedback"
        :placeholder="feedbackPlaceholder"
        @keydown.enter="onSubmit"
      />
      <button
        class="button small"
        :disabled="isButtonDisabled"
        :style="{
          background: widgetColor,
          borderColor: widgetColor,
          color: textColor,
        }"
      >
        <Spinner v-if="isUpdating && feedback" />
        <FluentIcon v-else icon="chevron-right" class="rtl:rotate-180" />
      </button>
    </form>
  </div>
</template>

<style lang="scss" scoped>
.customer-satisfaction {
  .ratings {
    .emoji-button {
      @apply shadow-none grayscale text-2xl outline-none transition-all duration-200;

      &.selected,
      &:hover,
      &:focus,
      &:active {
        @apply grayscale-0 scale-[1.32];
      }

      &.disabled {
        @apply cursor-not-allowed opacity-50 pointer-events-none;
      }
    }
  }

  .feedback-form {
    input {
      @apply h-10 dark:bg-n-alpha-black1 rtl:rounded-tl-[0] rtl:rounded-tr-[0] ltr:rounded-tr-[0] ltr:rounded-tl-[0] rtl:rounded-bl-[0] ltr:rounded-br-[0] ltr:rounded-bl-[0.25rem] rtl:rounded-br-[0.25rem] rounded-lg p-2.5 w-full focus:ring-0 focus:outline-n-brand;

      &::placeholder {
        @apply text-n-slate-10;
      }
    }

    .button {
      @apply rtl:rounded-tr-[0] rtl:rounded-tl-[0] appearance-none ltr:rounded-tl-[0] ltr:rounded-tr-[0] rtl:rounded-br-[0] ltr:rounded-bl-[0] rounded-lg h-auto ltr:-ml-px rtl:-mr-px text-xl;

      .spinner {
        display: block;
        padding: 0;
        height: auto;
        width: auto;
      }
    }
  }
}
</style>
