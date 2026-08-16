import { test, expect } from '@playwright/test';

/**
 * The endpoints the phone depends on.
 *
 * The mobile app has 1,930 tests and every one of them runs against a fake.
 * That is the right way to test a widget and it proves nothing about the
 * server: the paired-round bug earlier this week was a field the API did not
 * send, and no amount of Flutter testing could have found it because the fake
 * always sent it.
 *
 * So this asks the real deployment the questions the app asks, and checks the
 * fields the app reads rather than the status code.
 *
 * Read-only. Creating a round here would put a round in a golfer's history.
 */

const API = process.env.VSP_API_BASE_URL ?? 'https://vps-api.vnteki.com';

let headers: Record<string, string> = {};

test.beforeAll(async ({ request }) => {
  const res = await request.post(`${API}/auth/login`, {
    data: { identifier: 'admin@vsp.local', password: 'Admin2026' },
  });
  expect(res.status()).toBe(200);
  headers = { Authorization: `Bearer ${(await res.json()).accessToken}` };
});

test.describe('finding a course to play', () => {
  test('search answers with courses that have what the picker shows',
    async ({ request }) => {
      // `q`, not `query`. Spring ignores an unknown parameter, so asking with
      // the wrong name returns the unfiltered first page — which looked like
      // a broken search until the controller said otherwise.
      const res = await request.get(`${API}/courses/search?q=Long`, { headers });
      expect(res.status()).toBe(200);

      const body = await res.json();
      const list = body.content ?? body.items ?? body;
      expect(Array.isArray(list)).toBeTruthy();
      expect(list.length, 'Long Biên is in this database').toBeGreaterThan(0);

      for (const course of list.slice(0, 5)) {
        expect(course.courseId, 'a course with no id cannot be picked').toBeTruthy();
        expect(course.courseName, 'a course with no name is a blank row')
          .toBeTruthy();
        // The picker shows this badge and the download banner reads it.
        expect(
          Object.prototype.hasOwnProperty.call(course, 'hasPackage'),
          'the picker cannot tell which courses are downloadable',
        ).toBeTruthy();
      }
    });

  test('nearby answers for a point on a Vietnamese course', async ({ request }) => {
    // The 1st at Long Biên. `nearby` is what the app calls when a golfer opens
    // the picker on a course, and an empty answer there sends them searching
    // by name while standing on the tee.
    const res = await request.get(
      `${API}/courses/nearby?lat=21.0393&lng=105.8920&radiusMeters=5000`,
      { headers },
    );
    expect(res.status()).toBe(200);

    const body = await res.json();
    const list = body.content ?? body.items ?? body;
    expect(Array.isArray(list)).toBeTruthy();
    expect(list.length, 'standing on Long Biên and finding no course near')
      .toBeGreaterThan(0);
  });

  test('a search that matches nothing is an empty list, not an error',
    async ({ request }) => {
      const res = await request.get(
        `${API}/courses/search?q=zzzznotacourse`,
        { headers },
      );
      expect(res.status()).toBe(200);
      const body = await res.json();
      const list = body.content ?? body.items ?? body;
      expect(Array.isArray(list)).toBeTruthy();
      expect(list.length).toBe(0);
    });
});

test.describe('a round the golfer comes back to', () => {
  test('the history carries the second đường of a paired round',
    async ({ request }) => {
      // The bug this is written against: a round on Đường A + B stored its
      // pairing in round_segments and RoundResponse did not expose it, so the
      // app resumed on hole 10 of a nine-hole course and reported the hole as
      // unsurveyed. The field is only ever exercised by a real server.
      const res = await request.get(`${API}/rounds`, { headers });
      expect(res.status()).toBe(200);

      const body = await res.json();
      const rounds = body.content ?? body.items ?? body;
      expect(Array.isArray(rounds)).toBeTruthy();

      for (const round of rounds.slice(0, 10)) {
        expect(round.id).toBeTruthy();
        expect(round.courseId, 'a round with no course cannot be resumed')
          .toBeTruthy();
        // Present as a key even when null — a paired round needs the id and an
        // eighteen-hole round needs the explicit null. Absent means the field
        // was dropped from the response, which is what broke before.
        expect(
          Object.prototype.hasOwnProperty.call(round, 'backNineCourseId'),
          'RoundResponse no longer carries backNineCourseId',
        ).toBeTruthy();
      }
    });
});

test.describe('the map a golfer opens on the tee', () => {
  test('a hole with geometry serves it, and says who drew each shape',
    async ({ request }) => {
      const res = await request.get(`${API}/courses/1351/holes/1/features`, {
        headers,
      });
      expect(res.status()).toBe(200);

      const body = await res.json();
      for (const feature of body.features ?? []) {
        const props = feature.properties ?? {};
        // The app draws an unreviewed shape faint and dashed and says so on
        // screen. Without a source it cannot tell a mapper's green from a
        // model's, and the warning either appears on everything or nothing.
        expect(props.source, `${props.layerType} arrived with no source`)
          .toBeTruthy();
      }
    });

  test('asking for a hole number the course does not have is not a fault',
    async ({ request }) => {
      const res = await request.get(`${API}/courses/1351/holes/15/features`, {
        headers,
      });
      expect(res.status()).toBeLessThan(500);
    });

  test('a hole number outside the rules is refused, not accepted',
    async ({ request }) => {
      // @Min(1) @Max(18). A 400 here is the validation working; a 200 would
      // mean the app could ask for hole 99 and get an empty map instead of an
      // error it can report.
      const res = await request.get(`${API}/courses/1351/holes/99/features`, {
        headers,
      });
      expect(res.status()).toBeGreaterThanOrEqual(400);
      expect(res.status()).toBeLessThan(500);
    });
});
