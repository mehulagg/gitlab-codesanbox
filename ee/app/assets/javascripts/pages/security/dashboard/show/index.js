import initSecurityCharts from 'ee/security_dashboard/security_charts_init';
import { DASHBOARD_TYPES } from 'ee/security_dashboard/store/constants';

document.addEventListener('DOMContentLoaded', () => {
  initSecurityCharts(document.getElementById('js-security'), DASHBOARD_TYPES.INSTANCE);
});
