import { test, expect } from '@playwright/test';
import { watchForTrouble } from './trouble';

/**
 * Every page of the portal that needs no record to look at.
 *
 * The cheapest test in the suite and the one that finds the most: a page that
 * throws while rendering still draws a header and a nav, so a human clicking
 * round sees a screen that is merely empty and moves on.
 */
const STATIC_ROUTES = [
  '/dashboard',
  '/facilities',
  '/map-editor',
  '/pin-positions',
  '/course-conditions',
  '/alerts',
  '/corrections',
  '/admin/data-quality',
  '/tournaments',
  '/tournament/create',
  '/tournament-policies',
  '/users',
  '/market-integrations',
];

test.describe('every portal page opens without the browser objecting', () => {
  for (const route of STATIC_ROUTES) {
    test(`${route}`, async ({ page }) => {
      const problems = watchForTrouble(page);

      await page.goto(route);
      // Vue renders asynchronously and most of these pages fetch on mount, so
      // an assertion the instant navigation resolves would pass on a page
      // that is about to throw.
      await page.waitForLoadState('networkidle');

      expect(problems, `${route}\n${problems.join('\n')}`).toEqual([]);
      // A page that rendered nothing at all is a failure even in silence.
      // Counted rather than asserted visible: the app shell is several
      // siblings deep and a strict locator matches all of them.
      expect(await page.locator('#app *').count()).toBeGreaterThan(3);
    });
  }
});
