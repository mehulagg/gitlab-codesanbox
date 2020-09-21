import Vue from 'vue';
import { defaults } from 'lodash';
import ToolbarItem from '../toolbar_item.vue';
import buildHtmlToMarkdownRenderer from './build_html_to_markdown_renderer';
import buildCustomHTMLRenderer from './build_custom_renderer';
import { TOOLBAR_ITEM_CONFIGS } from '../constants';

const buildWrapper = propsData => {
  const instance = new Vue({
    render(createElement) {
      return createElement(ToolbarItem, propsData);
    },
  });

  instance.$mount();
  return instance.$el;
};

export const generateToolbarItem = config => {
  const { icon, classes, event, command, tooltip, isDivider } = config;

  if (isDivider) {
    return 'divider';
  }

  return {
    type: 'button',
    options: {
      el: buildWrapper({ props: { icon, tooltip }, class: classes }),
      event,
      command,
    },
  };
};

export const addCustomEventListener = (editorApi, event, handler) => {
  editorApi.eventManager.addEventType(event);
  editorApi.eventManager.listen(event, handler);
};

export const removeCustomEventListener = (editorApi, event, handler) =>
  editorApi.eventManager.removeEventHandler(event, handler);

export const addImage = ({ editor }, image) => editor.exec('AddImage', image);

export const getMarkdown = editorInstance => editorInstance.invoke('getMarkdown');

/**
 * This function allow us to extend Toast UI HTML to Markdown renderer. It is
 * a temporary measure because Toast UI does not provide an API
 * to achieve this goal.
 */
export const registerHTMLToMarkdownRenderer = editorApi => {
  const { renderer } = editorApi.toMarkOptions;

  Object.assign(editorApi.toMarkOptions, {
    renderer: renderer.constructor.factory(renderer, buildHtmlToMarkdownRenderer(renderer)),
  });
};

export const getEditorOptions = externalOptions => {
  return defaults({
    customHTMLRenderer: buildCustomHTMLRenderer(externalOptions?.customRenderers),
    toolbarItems: TOOLBAR_ITEM_CONFIGS.map(toolbarItem => generateToolbarItem(toolbarItem)),
  });
};
