import { test as setup, expect } from '@playwright/test';

/**
 * Signs in once, for the whole suite.
 *
 * Every test used to sign in for itself, which is 24 sign-ins in two minutes,
 * and the API rate-limits sign-in: the fourteenth attempt comes back 429
 * VSP-ERR-RATE-001. So the suite locked itself out part-way through and the
 * failure looked like a broken page rather than a suite hitting a wall it
 * built.
 *
 * That is worth writing down rather than just fixing, because it is exactly
 * what an operator would do to themselves — the portal reported the 429 as
 * "sai tài khoản hoặc mật khẩu", so the natural response is to retype the
 * password, which is another attempt, which extends the block.
 */

const STATE = 'storage/operator.json';

setup('sign in once as the operator', async ({ page }) => {
  await page.goto('/login');
  await page.locator('input[type="text"]').fill('admin@vsp.local');
  await page.locator('input[type="password"]').fill('Admin2026');
  await page.getByRole('button', { name: /Đăng nhập/ }).click();

  await page.waitForURL((url) => !url.pathname.startsWith('/login'), {
    timeout: 30_000,
  });
  // The session lives in localStorage, so it travels with the storage state.
  await expect(page.locator('#app')).toBeVisible();

  await page.context().storageState({ path: STATE });
});
