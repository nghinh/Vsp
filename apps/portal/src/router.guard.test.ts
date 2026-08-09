/**
 * The navigation guard, against the router the application actually ships.
 *
 * The portal had no guard at all: `router.ts` went from `createRouter(...)`
 * straight to `export default router`, with no `beforeEach`, no
 * `meta.requiresAuth` and no `beforeEnter` on any of its twenty routes. Typing
 * `/users` rendered the user-and-roles administration screen for anybody, and
 * the pages with silent mock fallbacks made the API's refusals look like data.
 *
 * Two things are under test and they are not the same thing:
 *
 *   1. that `resolveNavigation` decides correctly — exercised against the real
 *      route table, so every route the portal declares is covered, including
 *      any added after this file was written; and
 *   2. that the shipped router has it *installed* — exercised by driving
 *      `router.push` on the real router and watching where it lands.
 *
 * The second is why this file imports `./router` rather than rebuilding a
 * router from copied metadata. A guard test that reimplements the guard passes
 * just as happily when `router.beforeEach` is deleted from `router.ts`, which
 * is precisely the defect it is supposed to catch.
 *
 * Importing the real router needs two seams and no more. `createWebHistory`
 * wants a `window`, and there is no jsdom in this project, so it is swapped for
 * the memory history — the history implementation is not what is being tested.
 * A `push` that the guard *allows* would then load the page component, and some
 * of those pull in a WebGL map library, so the allow direction is asserted
 * through `resolveNavigation(router.resolve(path))`: the real function, given
 * the real route's real metadata, without mounting anything. A `push` the guard
 * *refuses* never reaches component resolution — vue-router loads lazy
 * components after every `beforeEach` has returned — so those run end to end on
 * the real router.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest';
import { resolveNavigation } from './guard';
import { signOut, __resetSessionForTests } from './auth';
import { COURSE_ROLES, ROLE, SUPER_ADMIN_ONLY, TOURNAMENT_ROLES } from './roles';

const fetchIdentity = vi.fn();

vi.mock('./api/auth', () => ({
  portalAuthApi: {
    login: vi.fn(),
    fetchIdentity: (...args: unknown[]) => fetchIdentity(...args),
  },
}));

vi.mock('vue-router', async () => {
  const actual = await vi.importActual<typeof import('vue-router')>('vue-router');
  return { ...actual, createWebHistory: actual.createMemoryHistory };
});

const { default: router } = await import('./router');

/**
 * Routes reachable by any signed-in operator, and why each one is.
 *
 * Written down rather than inferred, so that a route added tomorrow with no
 * `meta.roles` fails the coverage test below instead of quietly joining the
 * open set. The same shape as the API's own OPEN_BY_DESIGN list.
 */
const OPEN_TO_ANY_OPERATOR: Record<string, string> = {
  '/': 'redirect to /dashboard; carries no component',
  '/login': 'public by design — it is how a session is obtained',
  '/forbidden': 'what the guard shows someone it just refused',
  '/dashboard': 'operational summary; every role that reaches the shell may see it',
};
// /map-editor was here while it was a bare redirect to /facilities. It is now
// a real page that picks a course and opens the geometry editor, so it carries
// COURSE_ROLES like everything else that page leads to.

/** Substitute something concrete for `:id`, so a declared path resolves. */
const concrete = (path: string) => path.replace(/:[^/]+/g, '1');

/** Every route the shipped router declares. */
const realRoutes = () => router.getRoutes();

function signedInAs(...roles: string[]) {
  localStorage.setItem('vsp_portal_token', 'jwt-abc');
  fetchIdentity.mockResolvedValue({ golferAccountId: 13, roles });
}

/** The guard's verdict for a path, using the real route table's metadata. */
async function verdict(path: string) {
  const decision = await resolveNavigation(router.resolve(path));
  if (decision === true || decision === undefined) return 'allowed';
  return (decision as { path: string }).path;
}

beforeEach(() => {
  const store = new Map<string, string>();
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => void store.set(key, String(value)),
    removeItem: (key: string) => void store.delete(key),
    clear: () => store.clear(),
  });
  __resetSessionForTests();
  signOut();
  fetchIdentity.mockReset();
});

describe('the shipped router', () => {
  it('has the guard installed — a push to /users lands on /login, not on /users', async () => {
    await router.push('/users');

    expect(router.currentRoute.value.path).toBe('/login');
    expect(router.currentRoute.value.query.redirect).toBe('/users');
  });

  it('declares a role list for every route that is not deliberately open', () => {
    const undecided = realRoutes()
      .filter((route) => !route.meta?.roles)
      .map((route) => route.path)
      .filter((path) => !(path in OPEN_TO_ANY_OPERATOR));

    expect(undecided, 'routes with neither meta.roles nor an entry in OPEN_TO_ANY_OPERATOR').toEqual(
      [],
    );
  });

  it('keeps OPEN_TO_ANY_OPERATOR describing routes that still exist and are still open', () => {
    const paths = new Set(realRoutes().map((r) => r.path));
    const stale = Object.keys(OPEN_TO_ANY_OPERATOR).filter((path) => {
      const route = realRoutes().find((r) => r.path === path);
      return !paths.has(path) || Boolean(route?.meta?.roles);
    });

    expect(stale, 'entries naming a route that is gone or has since been gated').toEqual([]);
  });
});

describe('with no session', () => {
  it('refuses every route the portal declares, and says where to come back to', async () => {
    for (const route of realRoutes()) {
      if (route.meta?.public === true) continue;
      const path = concrete(route.path);
      expect(await verdict(path), `${route.path} with no session`).toBe('/login');
    }
  });

  it('drives the real router to /login from a role-gated route as well', async () => {
    await router.push('/facilities');

    expect(router.currentRoute.value.path).toBe('/login');
  });

  it('lets the login screen itself through', async () => {
    await router.push('/login');

    expect(router.currentRoute.value.path).toBe('/login');
  });

  it('does not send the login screen back to itself when a stored token is stale', async () => {
    localStorage.setItem('vsp_portal_token', 'stale');
    fetchIdentity.mockRejectedValue({ code: 'VSP-ERR-AUTH-001' });

    await router.push('/facilities');

    expect(router.currentRoute.value.path).toBe('/login');
    expect(localStorage.getItem('vsp_portal_token'), 'the rejected token is discarded').toBeNull();
  });

  it('never consults a role list stored in the browser', async () => {
    // The old auth.ts read roles from localStorage under this key, so writing
    // it is the closest thing to the attack the change exists to prevent.
    localStorage.setItem('vsp_portal_roles', JSON.stringify(['SUPER_ADMIN']));
    localStorage.setItem('vsp_portal_token', 'stale');
    fetchIdentity.mockRejectedValue({ code: 'VSP-ERR-AUTH-001' });

    expect(await verdict('/users')).toBe('/login');
  });
});

describe('with a session', () => {
  it('admits an operator to exactly the routes their role is listed on', async () => {
    signedInAs(ROLE.COURSE_ADMIN);

    for (const route of realRoutes()) {
      if (route.meta?.public === true) continue;
      const required = route.meta?.roles as readonly string[] | undefined;
      const expected =
        !required || required.includes(ROLE.COURSE_ADMIN) ? 'allowed' : '/forbidden';
      expect(await verdict(concrete(route.path)), route.path).toBe(expected);
    }
  });

  it('keeps a course admin out of user administration', async () => {
    signedInAs(ROLE.COURSE_ADMIN);

    expect(SUPER_ADMIN_ONLY).not.toContain(ROLE.COURSE_ADMIN);
    expect(await verdict('/users')).toBe('/forbidden');

    await router.push('/users');
    expect(router.currentRoute.value.path, 'on the real router too').toBe('/forbidden');
  });

  it('keeps a tournament director out of the course pages', async () => {
    signedInAs(ROLE.TOURNAMENT_DIRECTOR);

    expect(COURSE_ROLES).not.toContain(ROLE.TOURNAMENT_DIRECTOR);
    expect(await verdict('/facilities')).toBe('/forbidden');
    expect(await verdict('/courses/1/edit-geometry')).toBe('/forbidden');
    expect(await verdict('/tournaments')).toBe('allowed');
  });

  it('keeps an auditor out of everything but data quality and the open pages', async () => {
    signedInAs(ROLE.AUDITOR);

    expect(await verdict('/users')).toBe('/forbidden');
    expect(await verdict('/facilities')).toBe('/forbidden');
    expect(await verdict('/pin-positions')).toBe('/forbidden');
    expect(await verdict('/tournaments')).toBe('/forbidden');
    expect(await verdict('/admin/data-quality')).toBe('allowed');
    expect(await verdict('/dashboard')).toBe('allowed');
  });

  it('keeps a greenkeeper off the tournament screens', async () => {
    signedInAs(ROLE.GREENKEEPER);

    expect(TOURNAMENT_ROLES).not.toContain(ROLE.GREENKEEPER);
    expect(await verdict('/tournaments')).toBe('/forbidden');
    expect(await verdict('/tournament/create')).toBe('/forbidden');
    expect(await verdict('/pin-positions')).toBe('allowed');
  });

  it('admits a super admin to every route in the table', async () => {
    signedInAs(ROLE.SUPER_ADMIN);

    for (const route of realRoutes()) {
      if (route.meta?.public === true) continue;
      expect(await verdict(concrete(route.path)), route.path).toBe('allowed');
    }
  });

  it('ignores a role the browser adds to storage after sign-in', async () => {
    signedInAs(ROLE.AUDITOR);
    expect(await verdict('/users')).toBe('/forbidden');

    localStorage.setItem('vsp_portal_roles', JSON.stringify(['SUPER_ADMIN']));

    expect(await verdict('/users'), 'roles come from the server, not from storage').toBe(
      '/forbidden',
    );
  });

  it('asks the server for the roles rather than trusting the stored token alone', async () => {
    signedInAs(ROLE.SUPER_ADMIN);

    await verdict('/users');

    expect(fetchIdentity).toHaveBeenCalledWith('jwt-abc');
  });
});
