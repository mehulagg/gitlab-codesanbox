<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import statusCodes from '~/lib/utils/http_status';

export default {
  components: {
    GlButton,
  },
  inject: {
    resetMinutesPath: {
      type: String,
      default: '',
    },
  },
  methods: {
    resetPipelineMinutes() {
      axios
        .post(this.resetMinutesPath)
        .then(resp => {
          if (resp.status === statusCodes.OK) {
            this.$toast.show(__('User pipeline minutes were successfully reset.'));
          }
        })
        .catch(() =>
          this.$toast.show(__('There was an error resetting user pipeline minutes.'), {
            type: 'error',
          }),
        );
    },
  },
};
</script>
<template>
  <div class="bs-callout clearfix gl-mt-0 gl-mb-0">
    <h4>
      {{ s__('SharedRunnersMinutesSettings|Reset used pipeline minutes') }}
    </h4>
    <p>
      {{
        s__(
          'SharedRunnersMinutesSettings|By resetting the pipeline minutes for this namespace, the currently used minutes will be set to zero.',
        )
      }}
    </p>
    <gl-button @click="resetPipelineMinutes">
      {{ s__('SharedRunnersMinutesSettings|Reset pipeline minutes') }}
    </gl-button>
  </div>
</template>
