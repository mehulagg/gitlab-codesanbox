<script>
import { GlIcon } from '@gitlab/ui';
import '~/lib/utils/datetime_utility';
import tooltip from '~/vue_shared/directives/tooltip';
import timeagoMixin from '~/vue_shared/mixins/timeago';

export default {
  directives: {
    tooltip,
  },
  components: { GlIcon },
  mixins: [timeagoMixin],
  props: {
    finishedTime: {
      type: String,
      required: true,
    },
    duration: {
      type: Number,
      required: true,
    },
  },
  computed: {
    hasDuration() {
      return this.duration > 0;
    },
    hasFinishedTime() {
      return this.finishedTime !== '';
    },
    durationFormatted() {
      const date = new Date(this.duration * 1000);

      let hh = date.getUTCHours();
      let mm = date.getUTCMinutes();
      let ss = date.getSeconds();

      // left pad
      if (hh < 10) {
        hh = `0${hh}`;
      }
      if (mm < 10) {
        mm = `0${mm}`;
      }
      if (ss < 10) {
        ss = `0${ss}`;
      }

      return `${hh}:${mm}:${ss}`;
    },
  },
};
</script>
<template>
  <div class="table-section section-15 pipelines-time-ago">
    <div class="table-mobile-header" role="rowheader">{{ s__('Pipeline|Duration') }}</div>
    <div class="table-mobile-content">
      <p v-if="hasDuration" class="duration">
        <gl-icon name="timer" class="gl-vertical-align-baseline!" aria-hidden="true" />
        {{ durationFormatted }}
      </p>

      <p v-if="hasFinishedTime" class="finished-at d-none d-sm-none d-md-block">
        <gl-icon name="calendar" class="gl-vertical-align-baseline!" aria-hidden="true" />

        <time
          v-tooltip
          :title="tooltipTitle(finishedTime)"
          data-placement="top"
          data-container="body"
        >
          {{ timeFormatted(finishedTime) }}
        </time>
      </p>
    </div>
  </div>
</template>
