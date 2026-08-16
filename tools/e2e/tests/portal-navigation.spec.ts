import { test, expect } from '@playwright/test';
import { watchForTrouble } from './trouble';

/**
 * Getting around the portal the way an operator does: by clicking.
 *
 * The page sweep proves each route renders when typed into the address bar.
 * That is not the same as the nav working — a link pointing at a route that
 * does not exist lands on a blank page, and typing the correct URL by hand
 * would never find it.
 */

test('every link in the nav goes somewhere that renders', async ({ page }) => {
  const problems = watchForTrouble(page);
  await page.goto('/dashboard');
  await page.waitForLoadState('networkidle');

  const hrefs = await page.locator('nav a[href^="/"]').evaluateAll((links) =>
    Array.from(new Set(links.map((a) => (a as HTMLAnchorElement).getAttribute('href')!))),
  );
  expect(hrefs.length, 'a portal with no navigation is a portal with one page')
    .toBeGreaterThan(0);

  for (const href of hrefs) {
    await page.goto(href);
    await page.waitForLoadState('networkidle');
    // The router's catch-all would leave the operator on a screen with a
    // header and nothing under it.
    expect(page.url(), `${href} redirected away`).toContain(href);
    expect(await page.locator('#app *').count(), `${href} rendered nothing`)
      .toBeGreaterThan(3);
  }

  expect(problems, problems.join('\n')).toEqual([]);
});

test.describe('a caller with no session', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test('is sent to sign in rather than shown the portal', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForURL(/\/login/, { timeout: 15_000 });

    await expect(page.getByRole('heading', { name: 'Đăng nhập' })).toBeVisible();
  });

  test('is sent to sign in from a deep link too', async ({ page }) => {
    // The link an operator follows from a message, with a session that has
    // since expired. Landing on an empty course page would look like the
    // course was deleted.
    await page.goto('/courses/1352/holes');
    await page.waitForURL(/\/login/, { timeout: 15_000 });

    await expect(page.getByRole('heading', { name: 'Đăng nhập' })).toBeVisible();
  });

  test('a wrong password says so, and says nothing else', async ({ page }) => {
    await page.goto('/login');
    await page.locator('input[type="text"]').fill('admin@vsp.local');
    await page.locator('input[type="password"]').fill('not-the-password');
    await page.getByRole('button', { name: /Đăng nhập/ }).click();

    // The one case where blaming the credentials is correct. Every other
    // failure now has its own sentence — see signInErrorMessage.
    await expect(page.getByRole('alert')).toContainText('mật khẩu');
    await expect(page).toHaveURL(/\/login/);
  });
});
