<script>
import { createNamespacedHelpers } from 'vuex';
import { GlAlert } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import store from '../store/index';
import FeatureFlagForm from './form.vue';
import {
  LEGACY_FLAG,
  NEW_VERSION_FLAG,
  NEW_FLAG_ALERT,
  ROLLOUT_STRATEGY_ALL_USERS,
} from '../constants';
import { createNewEnvironmentScope } from '../store/modules/helpers';

import featureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

const { mapState, mapActions } = createNamespacedHelpers('new');

export default {
  store,
  components: {
    GlAlert,
    FeatureFlagForm,
  },
  mixins: [featureFlagsMixin()],
  props: {
    endpoint: {
      type: String,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
    environmentsEndpoint: {
      type: String,
      required: true,
    },
    projectId: {
      type: String,
      required: true,
    },
    showUserCallout: {
      type: Boolean,
      required: true,
    },
    userCalloutId: {
      default: '',
      type: String,
      required: false,
    },
    userCalloutsPath: {
      default: '',
      type: String,
      required: false,
    },
  },
  data() {
    return {
      userShouldSeeNewFlagAlert: this.showUserCallout,
    };
  },
  translations: {
    newFlagAlert: NEW_FLAG_ALERT,
  },
  computed: {
    ...mapState(['error']),
    scopes() {
      return [
        createNewEnvironmentScope(
          {
            environmentScope: '*',
            active: true,
          },
          this.glFeatures.featureFlagsPermissions,
        ),
      ];
    },
    version() {
      return this.hasNewVersionFlags ? NEW_VERSION_FLAG : LEGACY_FLAG;
    },
    hasNewVersionFlags() {
      return this.glFeatures.featureFlagsNewVersion;
    },
    shouldShowNewFlagAlert() {
      return !this.hasNewVersionFlags && this.userShouldSeeNewFlagAlert;
    },
    strategies() {
      return [{ name: ROLLOUT_STRATEGY_ALL_USERS, parameters: {}, scopes: [] }];
    },
  },
  created() {
    this.setEndpoint(this.endpoint);
    this.setPath(this.path);
  },
  methods: {
    ...mapActions(['createFeatureFlag', 'setEndpoint', 'setPath']),
    dismissNewVersionFlagAlert() {
      this.userShouldSeeNewFlagAlert = false;
      axios.post(this.userCalloutsPath, {
        feature_name: this.userCalloutId,
      });
    },
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="shouldShowNewFlagAlert"
      variant="warning"
      class="gl-my-5"
      @dismiss="dismissNewVersionFlagAlert"
    >
      {{ $options.translations.newFlagAlert }}
    </gl-alert>
    <h3 class="page-title">{{ s__('FeatureFlags|New feature flag') }}</h3>

    <div v-if="error.length" class="alert alert-danger">
      <p v-for="(message, index) in error" :key="index" class="mb-0">{{ message }}</p>
    </div>

    <feature-flag-form
      :project-id="projectId"
      :cancel-path="path"
      :submit-text="s__('FeatureFlags|Create feature flag')"
      :scopes="scopes"
      :strategies="strategies"
      :environments-endpoint="environmentsEndpoint"
      :version="version"
      @handleSubmit="data => createFeatureFlag(data)"
    />
  </div>
</template>
