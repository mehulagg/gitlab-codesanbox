import dastSiteProfilesQuery from 'ee/dast_profiles/graphql/dast_site_profiles.query.graphql';
import dastSiteProfilesDelete from 'ee/dast_profiles/graphql/dast_site_profiles_delete.mutation.graphql';
import dastScannerProfilesQuery from 'ee/dast_profiles/graphql/dast_scanner_profiles.query.graphql';
import dastScannerProfilesDelete from 'ee/dast_profiles/graphql/dast_scanner_profiles_delete.mutation.graphql';
import { dastProfilesDeleteResponse } from 'ee/dast_profiles/graphql/cache_utils';
import { s__ } from '~/locale';

const hasNoFeatureFlagOrIsEnabled = glFeatures => ([, { featureFlag }]) => {
  if (!featureFlag) {
    return true;
  }

  return Boolean(glFeatures[featureFlag]);
};

export const getProfileSettings = ({ createNewProfilePaths }, glFeatures) => {
  const settings = {
    siteProfiles: {
      profileType: 'siteProfiles',
      createNewProfilePath: createNewProfilePaths.siteProfile,
      graphQL: {
        query: dastSiteProfilesQuery,
        deletion: {
          mutation: dastSiteProfilesDelete,
          optimisticResponse: dastProfilesDeleteResponse({
            mutationName: 'siteProfilesDelete',
            payloadTypeName: 'DastSiteProfileDeletePayload',
          }),
        },
      },
      tableFields: ['profileName', 'targetUrl'],
      i18n: {
        createNewLinkText: s__('DastProfiles|Site Profile'),
        tabName: s__('DastProfiles|Site Profiles'),
        errorMessages: {
          fetchNetworkError: s__(
            'DastProfiles|Could not fetch site profiles. Please refresh the page, or try again later.',
          ),
          deletionNetworkError: s__(
            'DastProfiles|Could not delete site profile. Please refresh the page, or try again later.',
          ),
          deletionBackendError: s__('DastProfiles|Could not delete site profiles:'),
        },
      },
    },
    scannerProfiles: {
      profileType: 'scannerProfiles',
      createNewProfilePath: createNewProfilePaths.scannerProfile,
      graphQL: {
        query: dastScannerProfilesQuery,
        deletion: {
          mutation: dastScannerProfilesDelete,
          optimisticResponse: dastProfilesDeleteResponse({
            mutationName: 'scannerProfilesDelete',
            payloadTypeName: 'DastScannerProfileDeletePayload',
          }),
        },
      },
      featureFlag: 'securityOnDemandScansScannerProfiles',
      tableFields: ['profileName'],
      i18n: {
        createNewLinkText: s__('DastProfiles|Scanner Profile'),
        tabName: s__('DastProfiles|Scanner Profiles'),
        errorMessages: {
          fetchNetworkError: s__(
            'DastProfiles|Could not fetch scanner profiles. Please refresh the page, or try again later.',
          ),
          deletionNetworkError: s__(
            'DastProfiles|Could not delete scanner profile. Please refresh the page, or try again later.',
          ),
          deletionBackendError: s__('DastProfiles|Could not delete scanner profiles:'),
        },
      },
    },
  };

  return Object.fromEntries(
    Object.entries(settings).filter(hasNoFeatureFlagOrIsEnabled(glFeatures)),
  );
};
