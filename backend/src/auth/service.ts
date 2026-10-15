import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { SignJWT, jwtVerify } from 'jose';
import type { SqliteDatabase } from '../db/database.js';
import { authStore, type User } from './store.js';
import { hashPassword, verifyPassword } from './password.js';

const issuer = 'fieldops';
const audience = 'fieldops-ios';
const accessSeconds = 15 * 60;
const sessionSeconds = 30 * 24 * 60 * 60;
export class AuthError extends Error {
  constructor(public statusCode = 401, public code = 'UNAUTHORIZED', message = 'Authentication required') { super(message); }
}
export type AuthOptions = { secret: string; now?: () => number };
export function authService(db: SqliteDatabase, options: AuthOptions) {
  if (Buffer.byteLength(options.secret) < 32) throw new Error('AUTH_SECRET must contain at least 32 bytes');
  const key = new TextEncoder().encode(options.secret);
  const now = () => Math.floor((options.now ?? Date.now)() / 1000);
  const store = authStore(db);
  const dummy = hashPassword(randomBytes(32).toString('hex'));
  const digest = (token: string) => createHash('sha256').update(token).digest('hex');
  const publicUser = (user: User) => ({ id: user.id, email: user.email, role: user.role });
  async function tokens(user: User, sessionId: string, refreshToken: string, expiry: number) {
    const issued = now();
    const accessExpiry = Math.min(issued + accessSeconds, expiry);
    const accessToken = await new SignJWT({ sid: sessionId })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' }).setSubject(user.id)
      .setIssuer(issuer).setAudience(audience).setIssuedAt(issued).setExpirationTime(accessExpiry).sign(key);
    return { tokenType: 'Bearer', accessToken, refreshToken,
      accessTokenExpiresAt: new Date(accessExpiry * 1000).toISOString(),
      sessionExpiresAt: new Date(expiry * 1000).toISOString(), user: publicUser(user) };
  }
  return {
    async login(email: string, password: string) {
      const user = store.userByEmail(email.trim().toLowerCase());
      const valid = await verifyPassword(user?.password_hash ?? await dummy, password);
      if (!valid || !user?.active) throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid email or password');
      const id = randomUUID();
      const refresh = randomBytes(32).toString('base64url');
      const expiry = now() + sessionSeconds;
      store.createSession(id,user.id,expiry,digest(refresh));
      return tokens(user,id,refresh,expiry);
    },
    async refresh(token: string) {
      const next = randomBytes(32).toString('base64url');
      const row = store.rotate(digest(token),digest(next),now());
      if (!row) throw new AuthError();
      return tokens(row,row.session_id,next,row.expires_at);
    },
    async authenticate(header?: string) {
      if (!header?.startsWith('Bearer ')) throw new AuthError();
      let payload;
      try {
        ({ payload } = await jwtVerify(header.slice(7),key,{
          issuer, audience, algorithms: ['HS256'], typ: 'JWT', currentDate: new Date(now()*1000),
          requiredClaims: ['sub','sid','exp','iat'],
        }));
      } catch { throw new AuthError(); }
      if (typeof payload.sid !== 'string') throw new AuthError();
      const row = store.session(payload.sid);
      if (!row || row.id !== payload.sub || !row.active || row.revoked_at !== null || row.expires_at <= now()) throw new AuthError();
      return { user: publicUser(row), sessionId: row.session_id };
    },
    logout(sessionId: string) { store.revoke(sessionId,now()); },
  };
}
