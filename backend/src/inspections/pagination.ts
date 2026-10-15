import { DomainError } from './errors.js';
import type { ListQuery, PagePosition } from './types.js';
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function invalid(): never { throw new DomainError(400,'INVALID_CURSOR','Invalid cursor for this query'); }
export function pagination(query: ListQuery, scope: string) {
  const limit = Number(query.limit ?? 20);
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new DomainError(400,'INVALID_REQUEST','Limit must be between 1 and 100');
  }
  let position: PagePosition | undefined;
  if (query.cursor !== undefined) {
    const cursor = query.cursor;
    if (cursor.length > 2048 || !/^[A-Za-z0-9_-]+$/.test(cursor)) invalid();
    try {
      const buffer = Buffer.from(cursor,'base64url');
      if (buffer.toString('base64url') !== cursor) invalid();
      const decoded: unknown = JSON.parse(buffer.toString('utf8'));
      if (typeof decoded !== 'object' || decoded === null) invalid();
      const value = decoded as Record<string, unknown>;
      if (value.v !== 1 || value.scope !== scope || typeof value.id !== 'string' || !uuid.test(value.id)
        || typeof value.createdAt !== 'string' || new Date(value.createdAt).toISOString() !== value.createdAt) invalid();
      position = { id: value.id, createdAt: value.createdAt };
    } catch { invalid(); }
  }
  return { limit, position };
}
export function page<T extends PagePosition>(rows: T[], limit: number, scope: string) {
  const items = rows.slice(0,limit);
  const last = items.at(-1);
  const nextCursor = rows.length > limit && last
    ? Buffer.from(JSON.stringify({ v: 1, scope, createdAt: last.createdAt, id: last.id })).toString('base64url') : null;
  return { items, nextCursor };
}
