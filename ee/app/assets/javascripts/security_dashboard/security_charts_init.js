import Vue from 'vue';
import { DASHBOARD_TYPES } from 'ee/security_dashboard/store/constants';
import UnavailableState from './components/unavailable_state.vue';
import createStore from './store';
import createRouter from './router';
import apolloProvider from './graphql/provider';

import GroupSecurityCharts from './components/group_security_charts.vue';
import InstanceSecurityCharts from './components/instance_security_charts.vue';

export default (el, dashboardType) => {
  if (!el) {
    return null;
  }

  if (el.dataset.isUnavailable) {
    return new Vue({
      el,
      render(createElement) {
        return createElement(UnavailableState, {
          props: {
            link: el.dataset.dashboardDocumentation,
            svgPath: el.dataset.emptyStateSvgPath,
          },
        });
      },
    });
  }

  const props = {};
  const provide = {
    dashboardDocumentation: el.dataset.dashboardDocumentation,
    emptyStateSvgPath: el.dataset.emptyStateSvgPath,
  };

  let component;

  if (dashboardType === DASHBOARD_TYPES.GROUP) {
    component = GroupSecurityCharts;
    props.groupFullPath = el.dataset.groupFullPath;
  } else if (dashboardType === DASHBOARD_TYPES.INSTANCE) {
    component = InstanceSecurityCharts;
    provide.instanceDashboardSettingsPath = el.dataset.instanceDashboardSettingsPath;
  }

  const router = createRouter();
  const store = createStore({ dashboardType });

  return new Vue({
    el,
    store,
    router,
    apolloProvider,
    provide: () => provide,
    render(createElement) {
      return createElement(component, { props });
    },
  });
};
