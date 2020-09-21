import { pick } from 'lodash';
import createGqClient, { fetchPolicies } from '~/lib/graphql';
import { truncateSha } from '~/lib/utils/text_utility';
import {
  convertObjectPropsToCamelCase,
  convertObjectPropsToSnakeCase,
} from '~/lib/utils/common_utils';

/**
 * Converts a release object into a JSON object that can sent to the public
 * API to create or update a release.
 * @param {Object} release The release object to convert
 * @param {string} createFrom The ref to create a new tag from, if necessary
 */
export const releaseToApiJson = (release, createFrom = null) => {
  const name = release.name?.trim().length > 0 ? release.name.trim() : null;

  const milestones = release.milestones ? release.milestones.map(milestone => milestone.title) : [];

  return convertObjectPropsToSnakeCase(
    {
      name,
      tagName: release.tagName,
      ref: createFrom,
      description: release.description,
      milestones,
      assets: release.assets,
    },
    { deep: true },
  );
};

/**
 * Converts a JSON release object returned by the Release API
 * into the structure this Vue application can work with.
 * @param {Object} json The JSON object received from the release API
 */
export const apiJsonToRelease = json => {
  const release = convertObjectPropsToCamelCase(json, { deep: true });

  release.milestones = release.milestones || [];

  return release;
};

export const gqClient = createGqClient({}, { fetchPolicy: fetchPolicies.NO_CACHE });

const convertScalarProperties = graphQLRelease =>
  pick(graphQLRelease, [
    'name',
    'tagName',
    'tagPath',
    'descriptionHtml',
    'releasedAt',
    'upcomingRelease',
  ]);

const convertAssets = graphQLRelease => ({
  assets: {
    count: graphQLRelease.assets.count,
    sources: [...graphQLRelease.assets.sources.nodes],
    links: graphQLRelease.assets.links.nodes.map(l => ({
      ...l,
      linkType: l.linkType?.toLowerCase(),
    })),
  },
});

const convertEvidences = graphQLRelease => ({
  evidences: graphQLRelease.evidences.nodes.map(e => e),
});

const convertLinks = graphQLRelease => ({
  _links: {
    ...graphQLRelease.links,
    self: graphQLRelease.links?.selfUrl,
  },
});

const convertCommit = graphQLRelease => {
  if (!graphQLRelease.commit) {
    return {};
  }

  return {
    commit: {
      shortId: truncateSha(graphQLRelease.commit.sha),
      title: graphQLRelease.commit.title,
    },
    commitPath: graphQLRelease.commit.webUrl,
  };
};

const convertAuthor = graphQLRelease => ({ author: graphQLRelease.author });

const convertMilestones = graphQLRelease => ({
  milestones: graphQLRelease.milestones.nodes.map(m => ({
    ...m,
    webUrl: m.webPath,
    webPath: undefined,
    issueStats: {
      total: m.stats.totalIssuesCount,
      closed: m.stats.closedIssuesCount,
    },
    stats: undefined,
  })),
});

/**
 * Converts the response from the GraphQL endpoint into the
 * same shape as is returned from the Releases REST API.
 *
 * This allows the release components to use the response
 * from either endpoint interchangeably.
 *
 * @param response The response received from the GraphQL endpoint
 */
export const convertGraphQLResponse = response => {
  const releases = response.data.project.releases.nodes.map(r => ({
    ...convertScalarProperties(r),
    ...convertAssets(r),
    ...convertEvidences(r),
    ...convertLinks(r),
    ...convertCommit(r),
    ...convertAuthor(r),
    ...convertMilestones(r),
  }));

  const paginationInfo = {
    ...response.data.project.releases.pageInfo,
  };

  return { data: releases, paginationInfo };
};