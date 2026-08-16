/**
 * Portal session: the operator's bearer token, and the roles the server says
 * that token carries.
 *
 * What this file used to be, in full:
 *
 *   const DEV_TOKEN = "dev-portal-token";
 *   const DEFAULT_ROLES = ["COURSE_ADMIN", "SUPER_ADMIN"];
 *
 * with `getAuthToken()` and `getUserRoles()` falling back to those. Nothing in
 * the repository ever wrote the localStorage keys they read — there was no
 * login form, no call to any auth endpoint, and no router guard — so both
 * fallbacks were the only branch that ever ran. Every operator was SUPER_ADMIN,
 * decided by a constant in a file the browser downloads, and every request went
 * out as `Authorization: Bearer dev-portal-token`.
 *
 * That grant bought nothing at the API: `dev-portal-token` is not a JWT, so the
 * server treated every such request as anonymous and refused it. It was still
 * worth removing. A role the client hands itself is a claim the code around it
 * starts to believe — the geometry editor already gated its save button on this
 * one — and the day the portal is handed a real token, a client-side
 * SUPER_ADMIN is the thing deciding what to show a caller who may be an
 * auditor. Authorisation has exactly one place it can live, and it is not here.
 *
 * So: the token is obtained by signing in, and is the only thing persisted.
 * Roles are never read from storage — they are fetched from `GET /admin/me` on
 * every load, because storage is writable by whoever has the browser open and
 * the server is not. Everything below decides what to *show*. What an operator
 * may *do* is decided by the API on every request, and nothing in this file can
 * widen it.
 */

import { portalAuthApi, type ApiError } from './api/auth';

const TOKEN_KEY = 'vsp_portal_token';
/** Cosmetic only — the name in the sidebar. Never read for a decision. */
const NAME_KEY = 'vsp_portal_display_name';

export interface PortalSession {
  token: string;
  golferAccountId: number;
  displayName: string;
  /** Role names exactly as the server spells them: SUPER_ADMIN, COURSE_ADMIN, … */
  roles: string[];
}

let session: PortalSession | null = null;
/** An in-flight or settled restore, so a burst of navigations makes one request. */
let restoring: Promise<PortalSession | null> | null = null;

function readStorage(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStorage(key: string, value: string | null): void {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    /* private mode, quota, or no storage at all — the session then lasts one tab */
  }
}

/** The current session, or null when nobody is signed in. */
export function getSession(): PortalSession | null {
  return session;
}

/**
 * The bearer token for API calls, or the empty string when signed out.
 *
 * Empty rather than a placeholder: a request with no credential should be
 * refused as one, not answered as somebody.
 */
export function getAuthToken(): string {
  return session?.token ?? '';
}

/**
 * The roles the server said this operator holds — empty until it has said so.
 *
 * Empty is the correct answer while unknown. The previous default of
 * `["COURSE_ADMIN", "SUPER_ADMIN"]` meant that an unauthenticated page load
 * rendered the full administrator navigation.
 */
export function getUserRoles(): string[] {
  return session ? [...session.roles] : [];
}

/** True when the operator holds at least one of `roles`; an empty list is no restriction. */
export function hasAnyRole(roles: readonly string[] | undefined): boolean {
  if (!roles || roles.length === 0) return true;
  const held = session?.roles ?? [];
  return roles.some((role) => held.includes(role));
}

/** Signals that the credentials were right but the account is not an operator. */
export const NOT_AN_OPERATOR = 'VSP-PORTAL-NOT-AN-OPERATOR';

/** Sign in, then ask the server what this token is allowed to be. */
export async function signIn(identifier: string, password: string): Promise<PortalSession> {
  const auth = await portalAuthApi.login(identifier, password);

  // Distinguished from a bad password on purpose. Both are refusals, but only
  // one of them is worth retyping, and an operator who has just had their role
  // revoked should be told that rather than doubt their password.
  const identity = await portalAuthApi
    .fetchIdentity(auth.accessToken)
    .catch((error: ApiError) => {
      throw { ...error, code: NOT_AN_OPERATOR } as ApiError;
    });

  session = {
    token: auth.accessToken,
    golferAccountId: auth.userId,
    displayName: auth.displayName ?? identifier,
    roles: identity.roles,
  };
  writeStorage(TOKEN_KEY, session.token);
  writeStorage(NAME_KEY, session.displayName);
  restoring = Promise.resolve(session);
  return session;
}

/** Forget the operator, here and in storage. */
export function signOut(): void {
  session = null;
  restoring = null;
  writeStorage(TOKEN_KEY, null);
  writeStorage(NAME_KEY, null);
}

/**
 * Re-establish the session from the stored token, asking the server for the
 * roles.
 *
 * A stored token the server no longer accepts — expired, revoked, or belonging
 * to an account whose roles have been taken away — ends in a signed-out portal
 * rather than in a half-session rendering navigation it cannot use. Any failure
 * clears the token; no branch assumes a role.
 */
export async function restoreSession(): Promise<PortalSession | null> {
  if (session) return session;
  if (restoring) return restoring;

  const token = readStorage(TOKEN_KEY);
  if (!token) return null;

  restoring = portalAuthApi
    .fetchIdentity(token)
    .then((identity) => {
      session = {
        token,
        golferAccountId: identity.golferAccountId,
        displayName: readStorage(NAME_KEY) ?? 'Operator',
        roles: identity.roles,
      };
      return session;
    })
    .catch(() => {
      signOut();
      return null;
    });

  return restoring;
}

/**
 * What to tell someone whose sign-in did not end in a session.
 *
 * There used to be two answers here: "not an operator", and — for everything
 * else that could possibly go wrong — "sai tài khoản hoặc mật khẩu". So a
 * portal that could not reach the API at all told the operator their password
 * was wrong, and an operator who believes that retypes it. Found by pointing a
 * browser at the deployed API from a dev origin: CORS refused the preflight,
 * `fetch` rejected before a request was ever sent, and the screen said the
 * credentials were bad. They were correct.
 *
 * The distinction is the same one the mobile app needed: a server that refused
 * you and a server you never reached are different facts, and only one of them
 * is about the password.
 */
export function signInErrorMessage(error: unknown): string {
  const api = error as (ApiError & { status?: number }) | undefined;

  if (api?.code === NOT_AN_OPERATOR) {
    return 'Tài khoản này không có quyền vận hành trên portal.';
  }
  // `fetch` rejects with a TypeError when the request never completed — the
  // server is down, the network is out, or CORS refused it. There is no
  // status because there was no response.
  if (error instanceof TypeError || (api && api.code === 'NETWORK')) {
    return 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
  }
  // The one that cannot resolve itself. The API rate-limits sign-in — 429
  // VSP-ERR-RATE-001, measured at the fourteenth attempt — and an operator
  // told their password is wrong will retype it, which is another attempt,
  // which extends the block. Saying "wait" is the only advice that ends it.
  if (api?.status === 429 || api?.code === 'VSP-ERR-RATE-001') {
    return 'Đã thử đăng nhập quá nhiều lần. Đợi một phút rồi thử lại.';
  }
  if (api?.status !== undefined && api.status >= 500) {
    return 'Máy chủ đang gặp sự cố. Thử lại sau ít phút.';
  }
  return 'Sai tài khoản hoặc mật khẩu.';
}

/** Test seam: drop the in-memory session without touching storage. */
export function __resetSessionForTests(): void {
  session = null;
  restoring = null;
}
