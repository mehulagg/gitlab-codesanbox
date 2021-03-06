import {
  isValidConfigurationEntity,
  isValidAnalyzerEntity,
  toSastCiConfigurationEntityInput,
} from 'ee/security_configuration/sast/components/utils';
import { makeEntities, makeAnalyzerEntities } from './helpers';

describe('isValidConfigurationEntity', () => {
  const validEntities = makeEntities(3);

  const invalidEntities = [
    null,
    undefined,
    [],
    {},
    ...makeEntities(1, { field: undefined }),
    ...makeEntities(1, { type: undefined }),
    ...makeEntities(1, { description: undefined }),
    ...makeEntities(1, { label: undefined }),
    ...makeEntities(1, { value: undefined }),
    ...makeEntities(1, { defaultValue: undefined }),
  ];

  it.each(validEntities)('returns true for a valid entity', entity => {
    expect(isValidConfigurationEntity(entity)).toBe(true);
  });

  it.each(invalidEntities)('returns false for an invalid entity', invalidEntity => {
    expect(isValidConfigurationEntity(invalidEntity)).toBe(false);
  });
});

describe('isValidAnalyzerEntity', () => {
  const validEntities = makeAnalyzerEntities(3);

  const invalidEntities = [
    null,
    undefined,
    [],
    {},
    ...makeAnalyzerEntities(1, { name: undefined }),
    ...makeAnalyzerEntities(1, { label: undefined }),
    ...makeAnalyzerEntities(1, { description: undefined }),
    ...makeAnalyzerEntities(1, { enabled: undefined }),
    ...makeAnalyzerEntities(1, { enabled: '' }),
  ];

  it.each(validEntities)('returns true for a valid entity', entity => {
    expect(isValidAnalyzerEntity(entity)).toBe(true);
  });

  it.each(invalidEntities)('returns false for an invalid entity', invalidEntity => {
    expect(isValidAnalyzerEntity(invalidEntity)).toBe(false);
  });
});

describe('toSastCiConfigurationEntityInput', () => {
  let entity = makeEntities(1);

  describe('given a SastCiConfigurationEntity', () => {
    beforeEach(() => {
      [entity] = makeEntities(1);
    });

    it('returns a SastCiConfigurationEntityInput object', () => {
      expect(toSastCiConfigurationEntityInput(entity)).toEqual({
        field: entity.field,
        defaultValue: entity.defaultValue,
        value: entity.value,
      });
    });
  });
});
