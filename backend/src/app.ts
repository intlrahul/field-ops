import Fastify from 'fastify';
import { AuthError, authService, type AuthOptions } from './auth/service.js';
import { authRoutes } from './auth/routes.js';
import type { SqliteDatabase } from './db/database.js';

export function buildApp(db: SqliteDatabase, logger = false, authOptions?: AuthOptions) {
  const app = Fastify({ logger: logger ? { redact: ['req.headers.authorization', 'req.headers.cookie'] } : false,
    bodyLimit: 16384, ajv: { customOptions: { removeAdditional: false } } });
  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof AuthError) {
      if (error.statusCode === 401) reply.header('WWW-Authenticate','Bearer');
      return reply.code(error.statusCode).send({ error: { code: error.code, message: error.message } });
    }
    const status = typeof error === 'object' && error !== null && 'statusCode' in error && typeof error.statusCode === 'number' ? error.statusCode : 500;
    if (status < 500) return reply.code(status).send({ error: {
      code: status === 429 ? 'RATE_LIMITED' : 'INVALID_REQUEST',
      message: status === 429 ? 'Too many requests; try again later' : 'Invalid request',
    } });
    app.log.error({ err: error }, 'Request failed');
    return reply.code(500).send({ error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } });
  });
  app.setNotFoundHandler(async (_req, reply) => reply.code(404).send({ error: { code: 'NOT_FOUND', message: 'Route not found' } }));
  if (authOptions) {
    const auth = authService(db, authOptions);
    app.register(async scope => authRoutes(scope, auth));
  }
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
