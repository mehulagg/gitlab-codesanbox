import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import SuggestionDiffHeader from '~/vue_shared/components/markdown/suggestion_diff_header.vue';

const DEFAULT_PROPS = {
  batchSuggestionsCount: 2,
  canApply: true,
  isApplied: false,
  isBatched: false,
  isApplyingBatch: false,
  helpPagePath: 'path_to_docs',
};

describe('Suggestion Diff component', () => {
  let wrapper;

  const createComponent = (props, glFeatures = {}) => {
    wrapper = shallowMount(SuggestionDiffHeader, {
      propsData: {
        ...DEFAULT_PROPS,
        ...props,
      },
      provide: {
        glFeatures: {
          batchSuggestions: true,
          ...glFeatures,
        },
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  const findApplyButton = () => wrapper.find('.js-apply-btn');
  const findApplyBatchButton = () => wrapper.find('.js-apply-batch-btn');
  const findAddToBatchButton = () => wrapper.find('.js-add-to-batch-btn');
  const findRemoveFromBatchButton = () => wrapper.find('.js-remove-from-batch-btn');
  const findHeader = () => wrapper.find('.js-suggestion-diff-header');
  const findHelpButton = () => wrapper.find('.js-help-btn');
  const findLoading = () => wrapper.find(GlLoadingIcon);

  it('renders a suggestion header', () => {
    createComponent();

    const header = findHeader();

    expect(header.exists()).toBe(true);
    expect(header.html().includes('Suggested change')).toBe(true);
  });

  it('renders a help button', () => {
    createComponent();

    expect(findHelpButton().exists()).toBe(true);
  });

  it('renders apply suggestion and add to batch buttons', () => {
    createComponent();

    const applyBtn = findApplyButton();
    const addToBatchBtn = findAddToBatchButton();

    expect(applyBtn.exists()).toBe(true);
    expect(applyBtn.html().includes('Apply suggestion')).toBe(true);

    expect(addToBatchBtn.exists()).toBe(true);
    expect(addToBatchBtn.html().includes('Add suggestion to batch')).toBe(true);
  });

  describe('when apply suggestion is clicked', () => {
    beforeEach(() => {
      createComponent();

      findApplyButton().vm.$emit('click');
    });

    it('emits apply', () => {
      expect(wrapper.emitted().apply).toEqual([[expect.any(Function)]]);
    });

    it('does not render apply suggestion and add to batch buttons', () => {
      expect(findApplyButton().exists()).toBe(false);
      expect(findAddToBatchButton().exists()).toBe(false);
    });

    it('shows loading', () => {
      expect(findLoading().exists()).toBe(true);
      expect(wrapper.text()).toContain('Applying suggestion...');
    });

    it('when callback of apply is called, hides loading', () => {
      const [callback] = wrapper.emitted().apply[0];

      callback();

      return wrapper.vm.$nextTick().then(() => {
        expect(findApplyButton().exists()).toBe(true);
        expect(findLoading().exists()).toBe(false);
      });
    });
  });

  describe('when add to batch is clicked', () => {
    it('emits addToBatch', () => {
      createComponent();

      findAddToBatchButton().vm.$emit('click');

      expect(wrapper.emitted().addToBatch).toEqual([[]]);
    });
  });

  describe('when remove from batch is clicked', () => {
    it('emits removeFromBatch', () => {
      createComponent({ isBatched: true });

      findRemoveFromBatchButton().vm.$emit('click');

      expect(wrapper.emitted().removeFromBatch).toEqual([[]]);
    });
  });

  describe('apply suggestions is clicked', () => {
    it('emits applyBatch', () => {
      createComponent({ isBatched: true });

      findApplyBatchButton().vm.$emit('click');

      expect(wrapper.emitted().applyBatch).toEqual([[]]);
    });
  });

  describe('when isBatched is true', () => {
    it('shows remove from batch and apply batch buttons and displays the batch count', () => {
      createComponent({
        batchSuggestionsCount: 9,
        isBatched: true,
      });

      const applyBatchBtn = findApplyBatchButton();
      const removeFromBatchBtn = findRemoveFromBatchButton();

      expect(removeFromBatchBtn.exists()).toBe(true);
      expect(removeFromBatchBtn.html().includes('Remove from batch')).toBe(true);

      expect(applyBatchBtn.exists()).toBe(true);
      expect(applyBatchBtn.html().includes('Apply suggestions')).toBe(true);
      expect(applyBatchBtn.html().includes(String('9'))).toBe(true);
    });

    it('hides add to batch and apply buttons', () => {
      createComponent({
        isBatched: true,
      });

      expect(findApplyButton().exists()).toBe(false);
      expect(findAddToBatchButton().exists()).toBe(false);
    });

    describe('when isBatched and isApplyingBatch are true', () => {
      it('shows loading', () => {
        createComponent({
          isBatched: true,
          isApplyingBatch: true,
        });

        expect(findLoading().exists()).toBe(true);
        expect(wrapper.text()).toContain('Applying suggestions...');
      });

      it('adjusts message for batch with single suggestion', () => {
        createComponent({
          batchSuggestionsCount: 1,
          isBatched: true,
          isApplyingBatch: true,
        });

        expect(findLoading().exists()).toBe(true);
        expect(wrapper.text()).toContain('Applying suggestion...');
      });

      it('hides remove from batch and apply suggestions buttons', () => {
        createComponent({
          isBatched: true,
          isApplyingBatch: true,
        });

        expect(findRemoveFromBatchButton().exists()).toBe(false);
        expect(findApplyBatchButton().exists()).toBe(false);
      });
    });
  });

  describe('batchSuggestions feature flag is set to false', () => {
    beforeEach(() => {
      createComponent({}, { batchSuggestions: false });
    });

    it('disables add to batch buttons but keeps apply suggestion enabled', () => {
      expect(findApplyButton().exists()).toBe(true);
      expect(findAddToBatchButton().exists()).toBe(false);
      expect(findApplyButton().attributes('disabled')).not.toBe('true');
    });
  });

  describe('canApply is set to false', () => {
    beforeEach(() => {
      createComponent({ canApply: false });
    });

    it('disables apply suggestion and hides add to batch button', () => {
      expect(findApplyButton().exists()).toBe(true);
      expect(findAddToBatchButton().exists()).toBe(false);
      expect(findApplyButton().attributes('disabled')).toBe('true');
    });
  });

  describe('tooltip message for apply button', () => {
    it('renders correct tooltip message when button is applicable', () => {
      createComponent();
      expect(wrapper.vm.tooltipMessage).toBe('This also resolves this thread');
    });

    it('renders the inapplicable reason in the tooltip when button is not applicable', () => {
      const inapplicableReason = 'lorem';
      createComponent({ canApply: false, inapplicableReason });
      expect(wrapper.vm.tooltipMessage).toBe(inapplicableReason);
    });
  });
});