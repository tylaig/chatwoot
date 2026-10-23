<script>
import countries from 'shared/constants/countries.js';
import parsePhoneNumber from 'libphonenumber-js';
import {
  getActiveCountryCode,
  getActiveDialCode,
} from 'shared/components/PhoneInput/helper';

export default {
  props: {
    modelValue: {
      type: [String, Number],
      default: '',
    },
    placeholder: {
      type: String,
      default: '',
    },
    readonly: {
      type: Boolean,
      default: false,
    },
    styles: {
      type: Object,
      default: () => {},
    },
    error: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['blur', 'setCode', 'update:modelValue'],
  data() {
    return {
      selectedIndex: -1,
      showDropdown: false,
      searchCountry: '',
      activeCountryCode: getActiveCountryCode(),
      activeDialCode: getActiveDialCode(),
      phoneNumber: this.modelValue,
    };
  },
  computed: {
    countries() {
      return [
        {
          name: this.dropdownFirstItemName,
          dial_code: '',
          emoji: '',
          id: '',
        },
        ...countries,
      ];
    },
    dropdownFirstItemName() {
      return this.activeCountryCode ? 'Clear selection' : 'Select Country';
    },
    filteredCountriesBySearch() {
      return this.countries.filter(country => {
        const { name, dial_code, id } = country;
        const search = this.searchCountry.toLowerCase();
        return (
          name.toLowerCase().includes(search) ||
          dial_code.toLowerCase().includes(search) ||
          id.toLowerCase().includes(search)
        );
      });
    },
    activeCountry() {
      if (this.activeCountryCode) {
        return this.countries.find(
          country => country.id === this.activeCountryCode
        );
      }
      return '';
    },
  },
  watch: {
    modelValue() {
      const number = parsePhoneNumber(this.modelValue);
      if (number) {
        this.activeCountryCode = number.country;
        this.activeDialCode = `+${number.countryCallingCode}`;
        this.phoneNumber = this.modelValue.replace(
          `+${number.countryCallingCode}`,
          ''
        );
      }
    },
  },
  mounted() {
    this.setActiveCountry();
  },
  methods: {
    onOutsideClick(e) {
      if (
        this.showDropdown &&
        e.target !== this.$refs.dropdown &&
        !this.$refs.dropdown.contains(e.target)
      ) {
        this.closeDropdown();
      }
    },
    onChange(e) {
      this.phoneNumber = e.target.value;
      this.$emit('update:modelValue', e.target.value);
      this.$emit('setCode', this.activeDialCode);
    },
    onBlur(e) {
      this.$emit('blur', e.target.value);
    },
    onSearchCountry() {
      // Reset selected index to 0
      this.selectedIndex = 0;
    },
    moveUp() {
      if (!this.showDropdown) return;
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0);
      this.scrollToSelected();
    },
    moveDown() {
      if (!this.showDropdown) return;
      this.selectedIndex = Math.min(
        this.selectedIndex + 1,
        this.filteredCountriesBySearch.length - 1
      );
      this.scrollToSelected();
    },
    scrollToSelected() {
      this.$nextTick(() => {
        const dropdown = this.$refs.dropdown;
        const selectedItem = this.$refs.dropdownItem[this.selectedIndex];
        const dropdownSearchbarHeight = 40;
        if (selectedItem) {
          const selectedItemTop = selectedItem.offsetTop;
          dropdown.scrollTop = selectedItemTop - dropdownSearchbarHeight;
        }
      });
    },
    onSelectCountry(country) {
      if (!country || !this.showDropdown) return;
      this.activeCountryCode = country.id;
      this.searchCountry = '';
      this.activeDialCode = country.dial_code;
      this.$emit('setCode', country.dial_code);
      this.closeDropdown();
      this.$refs.phoneNumberInput.focus();
    },
    setActiveCountry() {
      const { phoneNumber } = this;
      if (!phoneNumber) return;
      const number = parsePhoneNumber(phoneNumber);
      if (number) {
        this.activeCountryCode = number.country;
        this.activeDialCode = number.countryCallingCode;
      }
    },
    toggleCountryDropdown() {
      this.showDropdown = !this.showDropdown;
      this.selectedIndex = -1;
      if (this.showDropdown) {
        this.$nextTick(() => {
          this.$refs.searchbar.focus();
        });
      }
    },
    closeDropdown() {
      this.selectedIndex = -1;
      this.showDropdown = false;
    },
  },
};
</script>

<template>
  <div class="relative phone-input--wrap">
    <div
      class="flex items-center justify-start h-10 border border-[#1A303D] focus-within:border-[#10B981] rounded-lg bg-[#0D1821] overflow-hidden transition-colors"
      :class="
        error
          ? '!border-red-500/80 mb-1'
          : 'mb-0 hover:border-[#10B981]/50'
      "
    >
      <div
        class="cursor-pointer px-2.5 flex items-center justify-center gap-1.5 bg-[#09131A] border-r border-[#1A303D] h-full shrink-0 select-none"
        @click.prevent="toggleCountryDropdown"
      >
        <span
          v-if="activeCountry?.id"
          :class="`fi fi-${activeCountry.id.toLowerCase()} size-4 rounded-[2px] shrink-0`"
        />
        <fluent-icon v-else icon="globe" class="fluent-icon" size="16" />
        <fluent-icon icon="chevron-down" class="fluent-icon text-slate-400" size="12" />
      </div>
      <span
        v-if="activeDialCode"
        class="flex items-center h-full ltr:pl-2.5 rtl:pr-2.5 text-sm font-medium text-slate-300 shrink-0 select-none"
      >
        {{ activeDialCode }}
      </span>
      <input
        ref="phoneNumberInput"
        :value="phoneNumber"
        type="tel"
        class="no-margin !h-full !mb-0 !rounded-none !outline-none !border-0 !shadow-none font-normal !w-full !bg-transparent text-sm text-white !px-2 placeholder:text-slate-500 focus:!border-0 focus:!shadow-none focus:!outline-none"
        :placeholder="placeholder"
        :readonly="readonly"
        :style="styles"
        @input="onChange"
        @blur="onBlur"
      />
    </div>
    <div
      v-if="showDropdown"
      ref="dropdown"
      v-on-clickaway="onOutsideClick"
      tabindex="0"
      class="z-50 absolute h-60 w-56 shadow-2xl overflow-y-auto top-11 rounded-lg px-0 pt-0 pb-1 bg-[#081218] border border-[#1A303D]"
      @keydown.prevent.up="moveUp"
      @keydown.prevent.down="moveDown"
      @keydown.prevent.enter="
        onSelectCountry(filteredCountriesBySearch[selectedIndex])
      "
    >
      <div
        class="sticky top-0 p-1 bg-white dark:bg-transparent backdrop-blur-[100px]"
      >
        <input
          ref="searchbar"
          v-model="searchCountry"
          type="text"
          :placeholder="$t('GENERAL.PHONE_INPUT.PLACEHOLDER')"
          class="!h-8 !mb-0 !text-sm !outline-n-brand dark:!outline-n-brand"
          @input="onSearchCountry"
        />
      </div>
      <div
        v-for="(country, index) in filteredCountriesBySearch"
        ref="dropdownItem"
        :key="index"
        class="flex items-center px-1 py-0 cursor-pointer h-7 hover:bg-n-alpha-1 dark:hover:bg-n-alpha-2"
        :class="{
          'bg-n-alpha-1 dark:bg-n-alpha-2': country.id === activeCountryCode,
          'bg-n-alpha-1 dark:bg-n-alpha-2': index === selectedIndex,
        }"
        @click="onSelectCountry(country)"
      >
        <span
          v-if="country.id"
          :class="`fi fi-${country.id.toLowerCase()} mr-2 size-3.5 rounded-[2px] shrink-0`"
        />

        <span
          class="max-w-[7.5rem] overflow-hidden text-ellipsis whitespace-nowrap"
        >
          {{ country.name }}
        </span>
        <span class="ml-1 text-xs text-n-slate-11">
          {{ country.dial_code }}
        </span>
      </div>
      <div v-if="filteredCountriesBySearch.length === 0">
        <span
          class="flex items-center justify-center mt-4 text-sm text-n-slate-10"
        >
          {{ $t('GENERAL.PHONE_INPUT.EMPTY_STATE') }}
        </span>
      </div>
    </div>
  </div>
</template>
