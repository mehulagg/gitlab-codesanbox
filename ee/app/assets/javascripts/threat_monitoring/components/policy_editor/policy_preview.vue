<script>
import { GlTabs, GlTab, GlSafeHtmlDirective } from '@gitlab/ui';

export default {
  components: {
    GlTabs,
    GlTab,
  },
  directives: {
    safeHtml: GlSafeHtmlDirective,
  },
  props: {
    policyYaml: {
      type: String,
      required: true,
    },
    policyDescription: {
      type: String,
      required: true,
    },
    initialTab: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    return { selectedTab: this.initialTab };
  },
  safeHtmlConfig: { ALLOWED_TAGS: ['strong', 'br'] },
};
</script>

<template>
  <gl-tabs v-model="selectedTab" content-class="gl-pt-0">
    <gl-tab :title="s__('NetworkPolicies|.yaml')">
      <pre class="gl-bg-white gl-rounded-top-left-none gl-rounded-top-right-none">{{
        policyYaml
      }}</pre>
    </gl-tab>
    <gl-tab :title="s__('NetworkPolicies|Rule')">
      <div
        v-safe-html:[$options.safeHtmlConfig]="policyDescription"
        class="gl-bg-white gl-rounded-top-left-none gl-rounded-top-right-none gl-rounded-bottom-left-base gl-rounded-bottom-right-base gl-py-3 gl-px-4 gl-border-1 gl-border-solid gl-border-gray-100"
      ></div>
    </gl-tab>
  </gl-tabs>
</template>
