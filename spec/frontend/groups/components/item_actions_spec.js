import Vue from 'vue';

import mountComponent from 'helpers/vue_mount_component_helper';
import itemActionsComponent from '~/groups/components/item_actions.vue';
import eventHub from '~/groups/event_hub';
import { mockParentGroupItem, mockChildren } from '../mock_data';

const createComponent = (group = mockParentGroupItem, parentGroup = mockChildren[0]) => {
  const Component = Vue.extend(itemActionsComponent);

  return mountComponent(Component, {
    group,
    parentGroup,
  });
};

describe('ItemActionsComponent', () => {
  let vm;

  beforeEach(() => {
    vm = createComponent();
  });

  afterEach(() => {
    vm.$destroy();
  });

  describe('methods', () => {
    describe('onLeaveGroup', () => {
      it('emits `showLeaveGroupModal` event with `group` and `parentGroup` props', () => {
        jest.spyOn(eventHub, '$emit').mockImplementation(() => {});
        vm.onLeaveGroup();

        expect(eventHub.$emit).toHaveBeenCalledWith(
          'showLeaveGroupModal',
          vm.group,
          vm.parentGroup,
        );
      });
    });
  });

  describe('template', () => {
    it('should render component template correctly', () => {
      expect(vm.$el.classList.contains('controls')).toBeTruthy();
    });

    it('should render Edit Group button with correct attribute values', () => {
      const group = { ...mockParentGroupItem };
      group.canEdit = true;
      const newVm = createComponent(group);

      const editBtn = newVm.$el.querySelector('a.edit-group');

      expect(editBtn).toBeDefined();
      expect(editBtn.classList.contains('no-expand')).toBeTruthy();
      expect(editBtn.getAttribute('href')).toBe(group.editPath);
      expect(editBtn.getAttribute('aria-label')).toBe('Edit group');
      expect(editBtn.dataset.originalTitle).toBe('Edit group');
      expect(editBtn.querySelectorAll('svg').length).not.toBe(0);
      expect(editBtn.querySelector('svg').getAttribute('data-testid')).toBe('settings-icon');

      newVm.$destroy();
    });

    it('should render Leave Group button with correct attribute values', () => {
      const group = { ...mockParentGroupItem };
      group.canLeave = true;
      const newVm = createComponent(group);

      const leaveBtn = newVm.$el.querySelector('a.leave-group');

      expect(leaveBtn).toBeDefined();
      expect(leaveBtn.classList.contains('no-expand')).toBeTruthy();
      expect(leaveBtn.getAttribute('href')).toBe(group.leavePath);
      expect(leaveBtn.getAttribute('aria-label')).toBe('Leave this group');
      expect(leaveBtn.dataset.originalTitle).toBe('Leave this group');
      expect(leaveBtn.querySelectorAll('svg').length).not.toBe(0);
      expect(leaveBtn.querySelector('svg').getAttribute('data-testid')).toBe('leave-icon');

      newVm.$destroy();
    });
  });
});
