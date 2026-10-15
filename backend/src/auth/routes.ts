import rateLimit from '@fastify/rate-limit';
import type { FastifyInstance } from 'fastify';
import type { authService } from './service.js';

export async function authRoutes(app: FastifyInstance, auth: ReturnType<typeof authService>) {
  await app.register(rateLimit, { global: false, errorResponseBuilder: () => ({
    statusCode: 429, error: { code: 'RATE_LIMITED', message: 'Too many requests; try again later' },
  }) });
  app.addHook('onSend', async (_req, reply) => { reply.header('Cache-Control','no-store'); });
  app.post<{ Body: { email: string; password: string } }>('/auth/login', {
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
    schema: { body: {
      type: 'object', required: ['email','password'], additionalProperties: false,
      properties: {
        email: { type: 'string', minLength: 3, maxLength: 254, pattern: '^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$' },
        password: { type: 'string', minLength: 1, maxLength: 1024 },
      },
    } },
  }, async req => auth.login(req.body.email,req.body.password));
  app.post<{ Body: { refreshToken: string } }>('/auth/refresh', {
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
    schema: { body: {
      type: 'object', required: ['refreshToken'], additionalProperties: false,
      properties: { refreshToken: { type: 'string', pattern: '^[A-Za-z0-9_-]{43}$' } },
    } },
  }, async req => auth.refresh(req.body.refreshToken));
  app.get('/me', async req => (await auth.authenticate(req.headers.authorization)).user);
  app.post('/auth/logout', async (req, reply) => {
    const session = await auth.authenticate(req.headers.authorization);
    auth.logout(session.sessionId);
    return reply.code(204).send();
  });
}
