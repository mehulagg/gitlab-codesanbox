import { shallowMount } from '@vue/test-utils';
import { GlDeprecatedBadge as GlBadge, GlPopover } from '@gitlab/ui';
import RemediatedBadge from 'ee/vulnerabilities/components/remediated_badge.vue';

const POPOVER_TITLE = 'Vulnerability remediated. Review before resolving.';
const POPOVER_CONTENT =
  'The vulnerability is no longer detected. Verify the vulnerability has been fixed or removed before changing its status.';

describe('Remediated badge component', () => {
  let wrapper;

  const createWrapper = () => {
    return shallowMount(RemediatedBadge);
  };

  beforeEach(() => {
    wrapper = createWrapper();
  });

  afterEach(() => wrapper.destroy());

  it('should link the badge and the popover', () => {
    const badge = wrapper.find(GlBadge);
    const { popover } = wrapper.vm.$refs;

    expect(popover.$attrs.target()).toEqual(badge.element);
  });

  it('should pass down the data to the popover', () => {
    const popoverAttributes = wrapper.find(GlPopover).attributes();

    expect(popoverAttributes.title).toEqual(POPOVER_TITLE);
    expect(popoverAttributes.content).toEqual(POPOVER_CONTENT);
  });
});
