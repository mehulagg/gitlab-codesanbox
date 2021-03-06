<script>
import axios from 'axios';
import { GlButton, GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import RelatedIssuesStore from '~/related_issues/stores/related_issues_store';
import RelatedIssuesBlock from '~/related_issues/components/related_issues_block.vue';
import { issuableTypesMap, PathIdSeparator } from '~/related_issues/constants';
import { sprintf, __, s__ } from '~/locale';
import { joinPaths, redirectTo } from '~/lib/utils/url_utility';
import { RELATED_ISSUES_ERRORS } from '../constants';
import { deprecatedCreateFlash as createFlash } from '~/flash';
import { getFormattedIssue, getAddRelatedIssueRequestParams } from '../helpers';

export default {
  name: 'VulnerabilityRelatedIssues',
  components: {
    RelatedIssuesBlock,
    GlButton,
    GlAlert,
    GlSprintf,
    GlLink,
  },
  props: {
    endpoint: {
      type: String,
      required: true,
    },
    canModifyRelatedIssues: {
      type: Boolean,
      required: false,
      default: false,
    },
    helpPath: {
      type: String,
      required: false,
      default: '',
    },
    projectPath: {
      type: String,
      required: true,
    },
  },
  data() {
    this.store = new RelatedIssuesStore();

    return {
      isProcessingAction: false,
      state: this.store.state,
      isFetching: false,
      isSubmitting: false,
      isFormVisible: false,
      errorCreatingIssue: false,
      inputValue: '',
    };
  },
  computed: {
    vulnerabilityProjectId() {
      return this.projectPath.replace(/^\//, ''); // Remove the leading slash, i.e. '/root/test' -> 'root/test'.
    },
    isIssueAlreadyCreated() {
      return Boolean(this.state.relatedIssues.find(i => i.lockIssueRemoval));
    },
  },
  inject: {
    vulnerabilityId: {
      type: Number,
    },
    projectFingerprint: {
      type: String,
    },
    createIssueUrl: {
      type: String,
    },
    reportType: {
      type: String,
    },
    issueTrackingHelpPath: {
      type: String,
    },
    permissionsHelpPath: {
      type: String,
    },
  },
  created() {
    this.fetchRelatedIssues();
  },
  methods: {
    createIssue() {
      this.isProcessingAction = true;
      this.errorCreatingIssue = false;

      return axios
        .post(this.createIssueUrl)
        .then(({ data: { web_url } }) => {
          redirectTo(web_url);
        })
        .catch(() => {
          this.isProcessingAction = false;
          this.errorCreatingIssue = true;
        });
    },
    toggleFormVisibility() {
      this.isFormVisible = !this.isFormVisible;
    },
    resetForm() {
      this.isFormVisible = false;
      this.store.setPendingReferences([]);
      this.inputValue = '';
    },
    addRelatedIssue({ pendingReferences }) {
      this.processAllReferences(pendingReferences);
      this.isSubmitting = true;
      const errors = [];

      // The endpoint can only accept one issue, so we need to do a separate call for each pending reference.
      const requests = this.state.pendingReferences.map(reference => {
        return axios
          .post(
            this.endpoint,
            getAddRelatedIssueRequestParams(reference, this.vulnerabilityProjectId),
          )
          .then(({ data }) => {
            const issue = getFormattedIssue(data.issue);
            // When adding an issue, the issue returned by the API doesn't have the vulnerabilityLinkId property; it's
            // instead in a separate ID property. We need to add it back in, or else the issue can't be deleted until
            // the page is refreshed.
            issue.vulnerabilityLinkId = issue.vulnerabilityLinkId ?? data.id;
            const index = this.state.pendingReferences.indexOf(reference);
            this.removePendingReference(index);
            this.store.addRelatedIssues(issue);
          })
          .catch(({ response }) => {
            errors.push({
              issueReference: reference,
              errorMessage: response.data?.message ?? RELATED_ISSUES_ERRORS.ISSUE_ID_ERROR,
            });
          });
      });

      return Promise.all(requests).then(() => {
        this.isSubmitting = false;
        const hasErrors = Boolean(errors.length);
        this.isFormVisible = hasErrors;

        if (hasErrors) {
          const messages = errors.map(error => sprintf(RELATED_ISSUES_ERRORS.LINK_ERROR, error));
          createFlash(messages.join(' '));
        }
      });
    },
    removeRelatedIssue(idToRemove) {
      const issue = this.state.relatedIssues.find(({ id }) => id === idToRemove);

      axios
        .delete(joinPaths(this.endpoint, issue.vulnerabilityLinkId.toString()))
        .then(() => {
          this.store.removeRelatedIssue(issue);
        })
        .catch(() => {
          createFlash(RELATED_ISSUES_ERRORS.UNLINK_ERROR);
        });
    },
    fetchRelatedIssues() {
      this.isFetching = true;

      axios
        .get(this.endpoint)
        .then(({ data }) => {
          const issues = data.map(getFormattedIssue);
          this.store.setRelatedIssues(
            issues.map(i => {
              const lockIssueRemoval = i.vulnerability_link_type === 'created';

              return {
                ...i,
                lockIssueRemoval,
                lockedMessage: lockIssueRemoval
                  ? s__('SecurityReports|Issues created from a vulnerability cannot be removed.')
                  : undefined,
              };
            }),
          );
        })
        .catch(() => {
          createFlash(__('An error occurred while fetching issues.'));
        })
        .finally(() => {
          this.isFetching = false;
        });
    },
    addPendingReferences({ untouchedRawReferences, touchedReference = '' }) {
      this.store.addPendingReferences(untouchedRawReferences);
      this.inputValue = touchedReference;
    },
    removePendingReference(indexToRemove) {
      this.store.removePendingRelatedIssue(indexToRemove);
    },
    processAllReferences(value = '') {
      const rawReferences = value.split(/\s+/).filter(reference => reference.trim().length > 0);
      this.addPendingReferences({ untouchedRawReferences: rawReferences });
    },
  },
  autoCompleteSources: gl?.GfmAutoComplete?.dataSources,
  issuableType: issuableTypesMap.ISSUE,
  pathIdSeparator: PathIdSeparator.Issue,
  i18n: {
    relatedIssues: __('Related issues'),
    createIssue: __('Create issue'),
    createIssueErrorTitle: __('Could not create issue'),
    createIssueErrorBody: s__(
      'SecurityReports|Ensure that %{trackingStart}issue tracking%{trackingEnd} is enabled for this project and you have %{permissionsStart}permission to create new issues%{permissionsEnd}.',
    ),
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-if="errorCreatingIssue"
      variant="danger"
      class="gl-mt-5"
      @dismiss="errorCreatingIssue = false"
    >
      <p class="gl-font-weight-bold gl-mb-2">{{ $options.i18n.createIssueErrorTitle }}</p>
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.createIssueErrorBody">
          <template #tracking="{ content }">
            <gl-link class="gl-display-inline-block" :href="issueTrackingHelpPath" target="_blank">
              {{ content }}
            </gl-link>
          </template>
          <template #permissions="{ content }">
            <gl-link class="gl-display-inline-block" :href="permissionsHelpPath" target="_blank">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
    </gl-alert>
    <related-issues-block
      :help-path="helpPath"
      :is-fetching="isFetching"
      :is-submitting="isSubmitting"
      :related-issues="state.relatedIssues"
      :can-admin="canModifyRelatedIssues"
      :pending-references="state.pendingReferences"
      :is-form-visible="isFormVisible"
      :input-value="inputValue"
      :auto-complete-sources="$options.autoCompleteSources"
      :issuable-type="$options.issuableType"
      :path-id-separator="$options.pathIdSeparator"
      :show-categorized-issues="false"
      @toggleAddRelatedIssuesForm="toggleFormVisibility"
      @addIssuableFormInput="addPendingReferences"
      @addIssuableFormBlur="processAllReferences"
      @addIssuableFormSubmit="addRelatedIssue"
      @addIssuableFormCancel="resetForm"
      @pendingIssuableRemoveRequest="removePendingReference"
      @relatedIssueRemoveRequest="removeRelatedIssue"
    >
      <template #headerText>
        {{ $options.i18n.relatedIssues }}
      </template>
      <template v-if="!isIssueAlreadyCreated && !isFetching" #headerActions>
        <gl-button
          ref="createIssue"
          variant="success"
          category="secondary"
          :loading="isProcessingAction"
          @click="createIssue"
        >
          {{ $options.i18n.createIssue }}
        </gl-button>
      </template>
    </related-issues-block>
  </div>
</template>
