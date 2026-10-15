import Fastify from 'fastify';
import type { SqliteDatabase } from './db/database.js';

export function buildApp(db: SqliteDatabase, logger = false) {
  const app = Fastify({ logger });
  app.get('/health', {
    schema: {
      response: {
        200: {
          type: 'object', required: ['status'], additionalProperties: false,
          properties: { status: { type: 'string', const: 'ok' } },
        },
        503: {
          type: 'object', required: ['error'], additionalProperties: false,
          properties: {
            error: {
              type: 'object', required: ['code', 'message'], additionalProperties: false,
              properties: { code: { type: 'string' }, message: { type: 'string' } },
            },
          },
        },
      },
    },
  }, async (_request, reply) => {
    try {
      db.prepare('SELECT version FROM schema_migrations LIMIT 1').get();
      return { status: 'ok' };
    } catch (error) {
      app.log.error({ err: error }, 'Database health check failed');
      return reply.code(503).send({
        error: { code: 'SERVICE_UNAVAILABLE', message: 'Service temporarily unavailable' },
      });
    }
  });
  return app;
}
