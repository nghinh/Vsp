import { test, expect } from '@playwright/test';
import { watchForTrouble } from './trouble';

/**
 * The pages that need a record to look at.
 *
 * Ids are resolved from the API at run time rather than written down. A suite
 * pinned to course 1351 stops testing the portal the day somebody retires
 * course 1351 — it starts testing whether 1351 exists, and passes or fails for
 * the wrong reason either way.
 *
 * Everything here reads. The portal's write paths — publish a version, build a
 * package, start a tournament — are deliberately not exercised, because this
 * runs against the live database.
 */

const API = process.env.VSP_API_BASE_URL ?? 'https://vps-api.vnteki.com';

interface Ids {
  facilityId?: number;
  courseId?: number;
  tournamentId?: string;
  policyId?: string;
}

const ids: Ids = {};

test.beforeAll(async ({ request }) => {
  const auth = await request.post(`${API}/auth/login`, {
    data: { identifier: 'admin@vsp.local', password: 'Admin2026' },
  });
  expect(auth.ok(), 'the API must accept the operator account').toBeTruthy();
  const token = (await auth.json()).accessToken as string;
  const headers = { Authorization: `Bearer ${token}` };

  // /admin/facilities, not /facilities — the portal's own path. Asking the
  // public one returned 404 and quietly skipped half this suite.
  const facilities = await request.get(`${API}/admin/facilities`, { headers });
  if (facilities.ok()) {
    const body = await facilities.json();
    const first = (body.content ?? body.items ?? body)[0];
    ids.facilityId = first?.id;
  }

  if (ids.facilityId) {
    const courses = await request.get(
      `${API}/admin/facilities/${ids.facilityId}/courses`,
      { headers },
    );
    if (courses.ok()) {
      const body = await courses.json();
      const first = (body.content ?? body.items ?? body)[0];
      ids.courseId = first?.id;
    }
  }

  const tournaments = await request.get(`${API}/tournaments`, { headers });
  if (tournaments.ok()) {
    const body = await tournaments.json();
    const first = (body.content ?? body.items ?? body)[0];
    ids.tournamentId = first?.id;
  }

  const policies = await request.get(`${API}/tournament-policies`, { headers });
  if (policies.ok()) {
    const body = await policies.json();
    const first = (body.content ?? body.items ?? body)[0];
    ids.policyId = first?.id;
  }
});

/** Opens [route] and fails on anything the browser objected to. */
async function opensCleanly(page: import('@playwright/test').Page, route: string) {
  const problems = watchForTrouble(page);
  await page.goto(route);
  await page.waitForLoadState('networkidle');
  expect(problems, `${route}\n${problems.join('\n')}`).toEqual([]);
  expect(await page.locator('#app *').count()).toBeGreaterThan(3);
}

test.describe('a page about one record', () => {
  test('a facility', async ({ page }) => {
    test.skip(!ids.facilityId, 'no facility on this deployment');
    await opensCleanly(page, `/facilities/${ids.facilityId}`);
  });

  test("a facility's courses", async ({ page }) => {
    test.skip(!ids.facilityId, 'no facility on this deployment');
    await opensCleanly(page, `/facilities/${ids.facilityId}/courses`);
  });

  test("a course's holes", async ({ page }) => {
    test.skip(!ids.courseId, 'no course on this deployment');
    await opensCleanly(page, `/courses/${ids.courseId}/holes`);
  });

  test("a course's tee sets", async ({ page }) => {
    test.skip(!ids.courseId, 'no course on this deployment');
    await opensCleanly(page, `/courses/${ids.courseId}/tee-sets`);
  });

  test('the geometry review screen', async ({ page }) => {
    test.skip(!ids.courseId, 'no course on this deployment');
    await opensCleanly(page, `/courses/${ids.courseId}/geometry-review`);
  });

  test('the geometry editor', async ({ page }) => {
    test.skip(!ids.courseId, 'no course on this deployment');
    await opensCleanly(page, `/courses/${ids.courseId}/edit-geometry`);
  });

  test("a course's versions", async ({ page }) => {
    test.skip(!ids.courseId, 'no course on this deployment');
    await opensCleanly(page, `/courses/${ids.courseId}/versions`);
  });

  test("a course's packages", async ({ page }) => {
    test.skip(!ids.courseId, 'no course on this deployment');
    await opensCleanly(page, `/courses/${ids.courseId}/packages`);
  });

  test('a tournament', async ({ page }) => {
    test.skip(!ids.tournamentId, 'no tournament on this deployment');
    await opensCleanly(page, `/tournament/${ids.tournamentId}`);
  });

  test("a tournament's outing sheet", async ({ page }) => {
    test.skip(!ids.tournamentId, 'no tournament on this deployment');
    await opensCleanly(page, `/tournament/${ids.tournamentId}/outing`);
  });

  test('a tournament policy', async ({ page }) => {
    test.skip(!ids.policyId, 'no policy on this deployment');
    await opensCleanly(page, `/tournament-policies/${ids.policyId}`);
  });
});

test.describe('a record that is not there', () => {
  // The portal has to say so rather than throw. An operator following a stale
  // link is the ordinary case, not an exceptional one.
  test('an unknown course does not break the page', async ({ page }) => {
    const problems = watchForTrouble(page);
    await page.goto('/courses/99999999/holes');
    await page.waitForLoadState('networkidle');

    const uncaught = problems.filter((p) => p.startsWith('uncaught:'));
    expect(uncaught, uncaught.join('\n')).toEqual([]);
    expect(await page.locator('#app *').count()).toBeGreaterThan(3);
  });
});
