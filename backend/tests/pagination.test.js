'use strict';

const { getPagination } = require('../src/utils/pagination');

describe('getPagination', () => {
  test('applique les valeurs par défaut', () => {
    expect(getPagination({})).toEqual({ page: 1, limit: 20, offset: 0 });
  });

  test('borne la page et la taille', () => {
    expect(getPagination({ page: '-4', limit: '999' })).toEqual({
      page: 1,
      limit: 100,
      offset: 0,
    });
  });

  test('calcule l’offset', () => {
    expect(getPagination({ page: '4', limit: '25' })).toEqual({
      page: 4,
      limit: 25,
      offset: 75,
    });
  });
});
