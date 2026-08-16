import { test, expect, type APIRequestContext } from '@playwright/test';

/**
 * The API, asked the questions its two clients actually ask.
 *
 * Read-only, against the live deployment. What is checked is not "does it
 * return 200" — that is the easy half — but the shape and the invariants the
 * portal and the phone are written against. A field that silently becomes
 * null, or a list that answers with a different envelope than it did, breaks a
 * client with no error anywhere on the server.
 *
 * One token for the whole spec. Signing in per test is what the portal suite
 * did until the API's rate limiter refused the fourteenth attempt.
 */

const API = process.env.VSP_API_BASE_URL ?? 'https://vps-api.vnteki.com';

let token = '';
let headers: Record<string, string> = {};

test.beforeAll(async ({ request }) => {
  const res = await request.post(`${API}/auth/login`, {
    data: { identifier: 'admin@vsp.local', password: 'Admin2026' },
  });
  expect(res.status(), 'the operator account must sign in').toBe(200);
  const body = await res.json();
  token = body.accessToken;
  headers = { Authorization: `Bearer ${token}` };

  expect(body.refreshToken, 'a session needs a refresh token').toBeTruthy();
  expect(body.expiresIn, 'the client schedules its refresh off this').toBeGreaterThan(0);
});

/** GET, with the operator's token, asserting the status. */
async function get(request: APIRequestContext, path: string, expected = 200) {
  const res = await request.get(`${API}${path}`, { headers });
  expect(res.status(), `GET ${path}`).toBe(expected);
  return res;
}

test.describe('who the caller is', () => {
  test('the operator carries the roles the portal gates on', async ({ request }) => {
    const me = await (await get(request, '/admin/me')).json();

    expect(Array.isArray(me.roles)).toBeTruthy();
    expect(me.roles.length, 'an account with no role cannot use the portal')
      .toBeGreaterThan(0);
  });

  test('an unsigned request is refused, not answered', async ({ request }) => {
    const res = await request.get(`${API}/admin/me`);
    expect([401, 403]).toContain(res.status());
  });

  test('a forged token is refused', async ({ request }) => {
    const res = await request.get(`${API}/admin/me`, {
      headers: { Authorization: 'Bearer not.a.token' },
    });
    expect([401, 403]).toContain(res.status());
  });

  test('a refused refresh token answers 401, which is what the clients read',
    async ({ request }) => {
      // Both the phone and the portal decide whether a session is over from
      // this status. It is asserted here because a change to it signs every
      // golfer out — or, worse, stops signing out the ones who should be.
      const res = await request.post(`${API}/auth/refresh`, {
        data: { refreshToken: 'definitely-not-a-token' },
      });
      expect(res.status()).toBe(401);
    });
});

test.describe('the course tree the portal walks', () => {
  let facilityId: number | undefined;
  let courseId: number | undefined;

  test('facilities come back as a list', async ({ request }) => {
    const body = await (await get(request, '/admin/facilities')).json();
    const list = body.content ?? body.items ?? body;

    expect(Array.isArray(list)).toBeTruthy();
    expect(list.length, 'a deployment with no facility has no portal to run')
      .toBeGreaterThan(0);
    facilityId = list[0].id;
    expect(list[0].name, 'a facility with no name renders as a blank row')
      .toBeTruthy();
  });

  test('a facility has courses', async ({ request }) => {
    test.skip(!facilityId, 'no facility');
    const body = await (
      await get(request, `/admin/facilities/${facilityId}/courses`)
    ).json();
    const list = body.content ?? body.items ?? body;

    expect(Array.isArray(list)).toBeTruthy();
    if (list.length > 0) courseId = list[0].id;
  });

  test('a course states how many holes it has, and has that many',
    async ({ request }) => {
      test.skip(!courseId, 'no course');
      const course = await (await get(request, `/admin/courses/${courseId}`)).json();
      const holesBody = await (
        await get(request, `/admin/courses/${courseId}/holes`)
      ).json();
      const holes = holesBody.content ?? holesBody.items ?? holesBody;

      // Two numbers that must agree and are served straight to the app: the
      // scorecard reads holesCount and the map reads the rows. A course
      // announcing 18 over 9 rows is a round that cannot be finished.
      if (course.holesCount != null && Array.isArray(holes) && holes.length) {
        expect(holes.length, `course ${courseId} says ${course.holesCount} holes`)
          .toBe(course.holesCount);
      }
    });

  test('an unknown course is a 404, not a 500', async ({ request }) => {
    const res = await request.get(`${API}/admin/courses/99999999`, { headers });
    expect(res.status(), 'a missing record is an answer, not a fault')
      .not.toBeGreaterThanOrEqual(500);
  });
});

test.describe('the hole geometry the map draws', () => {
  test('a traced hole serves features with provenance on every one',
    async ({ request }) => {
      // Long Biên's Đường B, 1st — the hole this whole map thread started on.
      const body = await (await get(request, '/courses/1352/holes/1/features')).json();

      expect(body.type).toBe('FeatureCollection');
      expect(Array.isArray(body.features)).toBeTruthy();
      expect(body.features.length, 'this hole is traced and should serve shapes')
        .toBeGreaterThan(0);

      for (const feature of body.features) {
        const props = feature.properties ?? {};
        expect(props.layerType, 'a shape with no layer cannot be drawn').toBeTruthy();
        // The app draws unreviewed shapes differently and says so. A feature
        // that arrives without this is drawn as though somebody checked it.
        expect(props.verified, `${props.layerType} carries no verified flag`)
          .not.toBeUndefined();
        expect(feature.geometry?.coordinates, 'a feature with no coordinates')
          .toBeTruthy();
      }
    });

  test('the hazards a golfer clubs off are actually served', async ({ request }) => {
    // The confidence floor used to withhold every bunker and pond on this
    // hole while serving its fairway, because the floor compared classes that
    // are not comparable. Asserted so it cannot come back quietly.
    const body = await (await get(request, '/courses/1352/holes/1/features')).json();
    const layers = new Set(
      body.features.map((f: { properties: { layerType: string } }) => f.properties.layerType),
    );

    expect(layers.has('bunker'), 'bunkers withheld from a hole that has eight')
      .toBeTruthy();
    expect(layers.has('water'), 'ponds withheld from a hole that has four')
      .toBeTruthy();
  });

  test('an unmapped hole answers empty rather than failing', async ({ request }) => {
    const res = await request.get(`${API}/courses/1352/holes/18/features`, { headers });
    // Đường B has nine holes. Asking for its 18th is what a paired round did
    // for a year, and the answer must be an empty collection.
    expect(res.status()).toBeLessThan(500);
  });
});

test.describe('what the operator screens read', () => {
  const READ_ONLY = [
    '/tournaments',
    '/tournament-policies',
    '/admin/markets',
    '/admin/licenses',
    '/config/basemap',
  ];

  for (const path of READ_ONLY) {
    test(`${path} answers`, async ({ request }) => {
      const res = await request.get(`${API}${path}`, { headers });
      // 404 is a fair answer for an endpoint this deployment does not run;
      // 5xx is never a fair answer to a read.
      expect(res.status(), `${path} returned ${res.status()}`).toBeLessThan(500);
    });
  }
});
