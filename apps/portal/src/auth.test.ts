import { beforeEach, describe, expect, it, vi } from 'vitest';

/**
 * Where the portal's idea of "who am I" comes from.
 *
 * The negative cases are the point. This module used to answer both questions
 * itself — `getAuthToken()` returned the constant `"dev-portal-token"` and
 * `getUserRoles()` returned `["COURSE_ADMIN", "SUPER_ADMIN"]` — with no login
 * flow anywhere in the portal to set anything else. Every test below that
 * asserts an empty role list is asserting that the client no longer awards
 * itself a role, and the two localStorage tests are asserting that it does not
 * accept one from a store the user can edit either.
 */

const login = vi.fn();
const fetchIdentity = vi.fn();

vi.mock('./api/auth', () => ({
  portalAuthApi: {
    login: (...args: unknown[]) => login(...args),
    fetchIdentity: (...args: unknown[]) => fetchIdentity(...args),
  },
}));

import {
  getAuthToken,
  getUserRoles,
  getSession,
  hasAnyRole,
  signIn,
  signOut,
  restoreSession,
  signInErrorMessage,
  NOT_AN_OPERATOR,
  __resetSessionForTests,
} from './auth';

const TOKEN_KEY = 'vsp_portal_token';

/**
 * A localStorage the tests own. Vitest runs these in Node, which has no Web
 * Storage, and the module under test is specifically about what does and does
 * not go into storage — so it gets a real one rather than exercising the
 * "storage unavailable" fallback in every case.
 */
function installStorage() {
  const store = new Map<string, string>();
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => void store.set(key, String(value)),
    removeItem: (key: string) => void store.delete(key),
    clear: () => store.clear(),
    key: (index: number) => [...store.keys()][index] ?? null,
    get length() {
      return store.size;
    },
  });
  return store;
}

let store: Map<string, string>;

beforeEach(() => {
  store = installStorage();
  __resetSessionForTests();
  login.mockReset();
  fetchIdentity.mockReset();
});

describe('signed out', () => {
  it('has no token', () => {
    expect(getAuthToken()).toBe('');
  });

  it('holds no roles', () => {
    expect(getUserRoles()).toEqual([]);
  });

  it('satisfies no role requirement', () => {
    expect(hasAnyRole(['SUPER_ADMIN'])).toBe(false);
    expect(hasAnyRole(['COURSE_ADMIN', 'AUDITOR'])).toBe(false);
  });

  it('restores nothing when no token was stored', async () => {
    await expect(restoreSession()).resolves.toBeNull();
    expect(fetchIdentity).not.toHaveBeenCalled();
  });
});

describe('roles come from the server and nowhere else', () => {
  it('ignores roles written into localStorage', async () => {
    localStorage.setItem('vsp_portal_roles', JSON.stringify(['SUPER_ADMIN']));

    expect(getUserRoles()).toEqual([]);
    expect(hasAnyRole(['SUPER_ADMIN'])).toBe(false);
  });

  it('takes the roles the identity endpoint reports, not the ones asked for', async () => {
    login.mockResolvedValue({ accessToken: 'jwt-abc', userId: 13, displayName: 'Dev Admin' });
    fetchIdentity.mockResolvedValue({ golferAccountId: 13, roles: ['AUDITOR'] });

    const session = await signIn('admin@vsp.local', 'Admin2026');

    expect(session.roles).toEqual(['AUDITOR']);
    expect(hasAnyRole(['AUDITOR'])).toBe(true);
    expect(hasAnyRole(['SUPER_ADMIN'])).toBe(false);
    expect(fetchIdentity).toHaveBeenCalledWith('jwt-abc');
  });

  it('re-asks the server on restore rather than trusting the stored token blindly', async () => {
    localStorage.setItem(TOKEN_KEY, 'jwt-from-last-time');
    fetchIdentity.mockResolvedValue({ golferAccountId: 13, roles: ['GREENKEEPER'] });

    const session = await restoreSession();

    expect(fetchIdentity).toHaveBeenCalledWith('jwt-from-last-time');
    expect(session?.roles).toEqual(['GREENKEEPER']);
  });

  it('signs out when the stored token is no longer accepted', async () => {
    localStorage.setItem(TOKEN_KEY, 'expired-jwt');
    fetchIdentity.mockRejectedValue({ code: 'VSP-ERR-AUTH-001', message: 'nope' });

    await expect(restoreSession()).resolves.toBeNull();
    expect(getUserRoles()).toEqual([]);
    expect(localStorage.getItem(TOKEN_KEY)).toBeNull();
  });

  it('makes one identity request for a burst of restores', async () => {
    localStorage.setItem(TOKEN_KEY, 'jwt-abc');
    fetchIdentity.mockResolvedValue({ golferAccountId: 13, roles: ['SUPER_ADMIN'] });

    await Promise.all([restoreSession(), restoreSession(), restoreSession()]);

    expect(fetchIdentity).toHaveBeenCalledTimes(1);
  });
});

describe('signing in', () => {
  it('persists the token and exposes it as the bearer', async () => {
    login.mockResolvedValue({ accessToken: 'jwt-abc', userId: 13, displayName: 'Dev Admin' });
    fetchIdentity.mockResolvedValue({ golferAccountId: 13, roles: ['SUPER_ADMIN'] });

    await signIn('admin@vsp.local', 'Admin2026');

    expect(getAuthToken()).toBe('jwt-abc');
    expect(localStorage.getItem(TOKEN_KEY)).toBe('jwt-abc');
    expect(getSession()?.displayName).toBe('Dev Admin');
  });

  it('never persists roles', async () => {
    login.mockResolvedValue({ accessToken: 'jwt-abc', userId: 13, displayName: 'Dev Admin' });
    fetchIdentity.mockResolvedValue({ golferAccountId: 13, roles: ['SUPER_ADMIN'] });

    await signIn('admin@vsp.local', 'Admin2026');

    expect([...store.values()].some((value) => value.includes('SUPER_ADMIN'))).toBe(false);
  });

  it('refuses a valid golfer who is not an operator, and keeps no session', async () => {
    login.mockResolvedValue({ accessToken: 'golfer-jwt', userId: 11, displayName: 'VSP Golfer' });
    fetchIdentity.mockRejectedValue({ code: 'VSP-ERR-AUTH-005', message: 'Insufficient permissions' });

    await expect(signIn('golfer@vsp.local', 'Golfer2026')).rejects.toMatchObject({
      code: NOT_AN_OPERATOR,
    });
    expect(getAuthToken()).toBe('');
    expect(getUserRoles()).toEqual([]);
    expect(localStorage.getItem(TOKEN_KEY)).toBeNull();
  });

  it('tells a non-operator apart from a wrong password', () => {
    expect(signInErrorMessage({ code: NOT_AN_OPERATOR })).toContain('quyền vận hành');
    expect(signInErrorMessage({ code: 'VSP-ERR-AUTH-001' })).toContain('mật khẩu');
  });

  it('does not fall back to a session when credentials are rejected', async () => {
    login.mockRejectedValue({ code: 'VSP-ERR-AUTH-001', message: 'Invalid credentials' });

    await expect(signIn('admin@vsp.local', 'wrong')).rejects.toBeTruthy();
    expect(getAuthToken()).toBe('');
    expect(getUserRoles()).toEqual([]);
  });
});

describe('signing out', () => {
  it('clears the session and the stored token', async () => {
    login.mockResolvedValue({ accessToken: 'jwt-abc', userId: 13, displayName: 'Dev Admin' });
    fetchIdentity.mockResolvedValue({ golferAccountId: 13, roles: ['SUPER_ADMIN'] });
    await signIn('admin@vsp.local', 'Admin2026');

    signOut();

    expect(getAuthToken()).toBe('');
    expect(getUserRoles()).toEqual([]);
    expect(getSession()).toBeNull();
    expect(localStorage.getItem(TOKEN_KEY)).toBeNull();
  });
});
