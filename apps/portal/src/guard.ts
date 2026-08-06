/**
 * The one decision that stands between a URL and a portal page.
 *
 * The portal had no navigation guard of any kind: `router.ts` went from
 * `createRouter(...)` straight to `export default router`, with no
 * `beforeEach`, no `meta.requiresAuth` and no `beforeEnter` on any of its
 * twenty routes. Typing `/users` rendered the user-and-roles administration
 * screen for anybody, and the pages with silent mock fallbacks made the API's
 * refusals look like data rather than like refusals.
 *
 * Two questions, in order. Is there a session — and if the answer is only "a
 * token is in localStorage", it is not settled until the server has confirmed
 * it, which is what `restoreSession` awaits. Then: does the session hold a role
 * this route lists? A route with no `meta.roles` is open to any operator, since
 * clearing `GET /admin/me` already means holding at least one role.
 *
 * This is presentation. The API authorises every request independently against
 * roles it reads from the database, so a guard that let something through would
 * produce a page of 403s rather than access. It exists so the portal shows an
 * operator the portal they actually have.
 *
 * It lives in its own module so that the test can exercise *this* function
 * rather than a copy of it kept in step by hand. A guard test that rebuilds the
 * guard proves the reimplementation correct and says nothing about the router
 * the application ships.
 */

import type { NavigationGuardReturn, RouteLocationNormalized } from 'vue-router';
import { hasAnyRole, restoreSession } from './auth';

/**
 * Only the two fields the decision reads. Stated rather than taking a whole
 * `RouteLocationNormalized` so that `router.resolve(path)` — which is how the
 * test asks the question without mounting a page — can be passed in directly.
 */
type Destination = Pick<RouteLocationNormalized, 'meta' | 'fullPath'>;

export async function resolveNavigation(to: Destination): Promise<NavigationGuardReturn> {
  if (to.meta.public === true) return true;

  const session = await restoreSession();
  if (!session) {
    return { path: '/login', query: { redirect: to.fullPath } };
  }

  const required = to.meta.roles as readonly string[] | undefined;
  if (!hasAnyRole(required)) {
    return { path: '/forbidden' };
  }

  return true;
}
