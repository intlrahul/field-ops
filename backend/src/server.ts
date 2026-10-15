import { buildApp } from './app.js';
import { migrate, openDatabase } from './db/database.js';

const port = Number(process.env.PORT ?? 3000);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('PORT must be an integer between 1 and 65535');
}
const db = openDatabase(process.env.DATABASE_PATH ?? 'data/fieldops.sqlite');
const app = buildApp(db, true);
app.addHook('onClose', async () => { db.close(); });
try {
  migrate(db);
  await app.listen({ port, host: process.env.HOST ?? '127.0.0.1' });
} catch (error) {
  app.log.error(error);
  await app.close();
  process.exitCode = 1;
}
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => {
    void app.close().catch((error: unknown) => {
      app.log.error(error);
      process.exitCode = 1;
    });
  });
}
