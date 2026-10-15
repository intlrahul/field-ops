# Authentication contract and local walkthrough

The API contract is [openapi.yaml](openapi.yaml). Docker is deferred. HTTP is for loopback development; HTTPS must be configured before sending real credentials across a network.

## Setup

From backend/:

```sh
npm ci
cp .env.example .env
node -e "console.log(require('node:crypto').randomBytes(32).toString('base64url'))"
```

Put the generated value in AUTH_SECRET inside .env. Set SEED_SUPERVISOR_PASSWORD and SEED_TECHNICIAN_PASSWORD to distinct development passwords of 12–1024 characters. The scripts load .env; process environment values take precedence. Secrets and passwords are not committed. An absent or short signing secret prevents server startup. Changing AUTH_SECRET invalidates existing access tokens; outstanding refresh tokens can still issue new access tokens.

```sh
npm run seed
npm run dev
```

Seed creates supervisor@fieldops.test and technician@fieldops.test, with random UUIDs and Argon2id password hashes. Rerunning it leaves existing accounts, passwords, and roles unchanged. Both passwords are required by the seed command even on reruns. Seeding is blocked with NODE_ENV=production. No public registration or role-changing API exists. The seed also adds a demo asset and assigned inspection; see ASSETS_INSPECTIONS.md.

## Requests

```sh
curl -i http://127.0.0.1:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"technician@fieldops.test","password":"YOUR_SEEDED_PASSWORD"}'
```

A successful login returns this shape (token strings below are placeholders):

```json
{
  "tokenType": "Bearer",
  "accessToken": "SIGNED_JWT",
  "refreshToken": "OPAQUE_REFRESH_TOKEN",
  "accessTokenExpiresAt": "2026-10-15T08:15:00.000Z",
  "sessionExpiresAt": "2026-11-14T08:00:00.000Z",
  "user": {
    "id": "0190b6c1-b11d-4db0-8891-124ddfa32784",
    "email": "technician@fieldops.test",
    "role": "technician"
  }
}
```

```sh
curl -i http://127.0.0.1:3000/me \
  -H 'Authorization: Bearer REPLACE_WITH_ACCESS_TOKEN'

curl -i http://127.0.0.1:3000/auth/refresh \
  -H 'Content-Type: application/json' \
  -d '{"refreshToken":"REPLACE_WITH_REFRESH_TOKEN"}'

curl -i -X POST http://127.0.0.1:3000/auth/logout \
  -H 'Authorization: Bearer REPLACE_WITH_CURRENT_ACCESS_TOKEN'
```

/me returns the user object. Refresh returns a new token pair with the same session deadline. Logout returns 204 with no body. Protected requests after logout return 401. All auth/profile responses have Cache-Control: no-store. Authenticated requests use bearer headers, not cookies; this is a native-client API.

Errors use {"error":{"code":"UNAUTHORIZED","message":"Authentication required"}}. Invalid credentials use INVALID_CREDENTIALS without distinguishing unknown, inactive, and incorrect-password accounts. Invalid bodies return 400 INVALID_REQUEST, missing/invalid/expired credentials return 401, and throttled requests return 429 RATE_LIMITED with Retry-After. Unknown routes use 404 NOT_FOUND; unexpected failures use 500 INTERNAL_ERROR without internal details. Body size is capped at 16 KiB (413 INVALID_REQUEST). Unexpected fields are rejected; clients cannot submit a role at login.

## Session and security decisions

- Passwords: established node-argon2 library, Argon2id with 19 MiB memory, two iterations, one lane. Unknown users still perform a password verification against a dummy hash; this reduces timing differences without claiming perfectly equal response times.
- Access tokens: jose signs/verifies HS256 JWTs using a configured random secret of at least 32 bytes. Verify issuer, audience, type, algorithm, signature, expiry, subject, and session ID. Access lifetime is 15 minutes, capped at session expiry. Claims contain no password or refresh token.
- Refresh tokens: 32 cryptographically random bytes encoded base64url. Only SHA-256 hashes are persisted; high-entropy tokens do not need password-style slow hashing. Retain consumed hashes for replay detection.
- One login creates one independent session; a 30-day absolute deadline does not slide on refresh. Epoch seconds are stored internally, UTC RFC 3339 timestamps exposed externally. A clock is injected for deterministic expiry tests.
- Rotation: consume the old token and insert the new hash in one immediate SQLite transaction. On reuse, revoke that session in a committed transaction and then return 401. Never throw inside the transaction in a way that rolls revocation back.
- Strict replay policy: if a refresh response is lost, retrying that consumed token revokes the session. Parallel refresh attempts produce one successful rotation and revoke its session when the other attempt reuses the token. The client must serialize refresh requests and require sign-in on rejection. There is no refresh retry grace period.
- Protected requests query the current session/user from SQLite. Logout and account deactivation take effect immediately despite an otherwise valid JWT. Current role comes from the database, not a stale token claim. Both roles may access /me; resource and role restrictions for inspection/supervisor operations arrive with those endpoints. Returning a role is not itself resource authorization.
- Logout requires an unexpired access token and revokes just that session. Repeated logout returns 401. If access has expired, refresh first; if already offline, discard local credentials and the server session eventually expires. Logout-all and account recovery are deferred.
- Login: five requests per source IP per minute; refresh: thirty. The limiter is bounded in-process state and resets on restart. It does not prevent distributed attacks. Trust-proxy is disabled; explicitly configure trusted proxy addresses before deploying behind a proxy so attackers cannot supply arbitrary client IPs. Requests behind an unconfigured proxy share a limit.
- Authorization headers/cookies are redacted in logs; bodies and returned tokens are not logged. Do not add credential/body logging.

## iOS expectations, no iOS implementation

Keep refresh tokens in Keychain and access tokens in memory initially. Replace the Keychain refresh token after each successful refresh before starting another. A crash before saving a rotated token may require signing in again. Do not store tokens in UserDefaults or logs. Clear local tokens at logout; handle 401 explicitly without endless retries. Token expiry does not decide whether locally cached inspection data may be viewed offline: that policy remains unresolved. Reconnecting always requires current server authorization.

## Deferred and limitations

HTTPS setup, Docker, password reset, email verification, user administration, session-management UI, logout-all, device binding, MFA, and expired-session/token cleanup are deferred. Consumed token records currently accumulate. In-memory IP throttling is suitable only for this single-instance learning slice. Inspection creation/list/details and workflow mutations now exist; the sync engine and offline-access policy remain pending.

Libraries: [node-argon2](https://github.com/ranisalt/node-argon2), [jose](https://github.com/panva/jose), [Fastify rate limiter](https://github.com/fastify/fastify-rate-limit).
