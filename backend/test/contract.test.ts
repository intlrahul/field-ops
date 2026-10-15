import SwaggerParser from '@apidevtools/swagger-parser';
import { fileURLToPath } from 'node:url';
import { expect, test } from 'vitest';

test('OpenAPI contract is valid and all references resolve', async () => {
  const api = await SwaggerParser.validate(fileURLToPath(new URL('../../docs/openapi.yaml',import.meta.url)));
  expect(Object.keys(api.paths ?? {}).sort()).toEqual([
    '/assets','/assets/{id}','/auth/login','/auth/logout','/auth/refresh','/health','/inspections','/inspections/{id}',
    '/inspections/{id}/checklist-items/{itemId}/result','/inspections/{id}/complete','/inspections/{id}/notes',
    '/inspections/{id}/readings/{readingId}','/inspections/{id}/start','/me',
  ]);
});
