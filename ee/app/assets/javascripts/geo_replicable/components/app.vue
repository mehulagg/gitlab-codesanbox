<script>
import { mapActions, mapState } from 'vuex';
import { GlLoadingIcon } from '@gitlab/ui';
import GeoReplicableFilterBar from './geo_replicable_filter_bar.vue';
import GeoReplicable from './geo_replicable.vue';
import GeoReplicableEmptyState from './geo_replicable_empty_state.vue';

export default {
  name: 'GeoReplicableApp',
  components: {
    GlLoadingIcon,
    GeoReplicableFilterBar,
    GeoReplicable,
    GeoReplicableEmptyState,
  },
  props: {
    geoReplicableEmptySvgPath: {
      type: String,
      required: true,
    },
    geoTroubleshootingLink: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState(['isLoading', 'replicableItems', 'useGraphQl']),
    hasReplicableItems() {
      return this.replicableItems.length > 0;
    },
  },
  created() {
    this.fetchReplicableItems();
  },
  methods: {
    ...mapActions(['fetchReplicableItems']),
  },
};
</script>

<template>
  <article class="geo-replicable-container">
    <!-- Filtering not currently supported via GraphQl -->
    <geo-replicable-filter-bar v-if="!useGraphQl" class="mb-3" />
    <gl-loading-icon v-if="isLoading" size="xl" />
    <template v-else>
      <geo-replicable v-if="hasReplicableItems" />
      <geo-replicable-empty-state
        v-else
        :geo-replicable-empty-svg-path="geoReplicableEmptySvgPath"
        :geo-troubleshooting-link="geoTroubleshootingLink"
      />
    </template>
  </article>
</template>
