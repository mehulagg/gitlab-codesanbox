<script>
import { mapGetters } from 'vuex';
import { deprecatedCreateFlash as Flash } from '~/flash';
import { __ } from '~/locale';
import Status from './status.vue';
import { OPENED, REOPENED } from '~/notes/constants';

export default {
  components: {
    Status,
  },
  props: {
    mediator: {
      required: true,
      type: Object,
      validator(mediatorObject) {
        return Boolean(mediatorObject.store);
      },
    },
  },
  computed: {
    ...mapGetters(['getNoteableData']),
    isOpen() {
      return this.getNoteableData.state === OPENED || this.getNoteableData.state === REOPENED;
    },
  },
  methods: {
    handleDropdownClick(status) {
      this.mediator.updateStatus(status).catch(() => {
        Flash(__('Error occurred while updating the issue status'));
      });
    },
  },
};
</script>

<template>
  <status
    :is-editable="mediator.store.editable && isOpen"
    :is-fetching="mediator.store.isFetching.status"
    :status="mediator.store.status"
    @onDropdownClick="handleDropdownClick"
  />
</template>
