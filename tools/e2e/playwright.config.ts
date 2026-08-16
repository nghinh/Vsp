import { defineConfig } from '@playwright/test';

/**
 * End-to-end tests for the portal and the API it talks to.
 *
 * The portal is served by Vite from apps/portal and pointed at a real API —
 * the deployed one by default, because the bugs worth finding here are the
 * ones between the two. A portal tested against a mock proves the mock.
 *
 * Nothing here writes. Every test signs in, reads, and asserts; the fixtures
 * that would need to create a tournament or publish a version are the ones
 * left out on purpose, because this suite runs against production data.
 */
export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list']],
  // One sign-in for the suite. Every spec then starts already authenticated,
  // which is both faster and the only way to stay under the API's sign-in
  // rate limit — see tests/auth.setup.ts.
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts/ },
    {
      name: 'portal',
      testIgnore: /auth\.setup\.ts/,
      dependencies: ['setup'],
      use: { storageState: 'storage/operator.json' },
    },
  ],
  use: {
    baseURL: process.env.PORTAL_URL ?? 'http://localhost:5173',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 15_000,
  },
  webServer: {
    // `--host` so the port is predictable, and the API base is injected here
    // rather than proxied: the dev proxy points at localhost:8080, which is
    // not where this deployment's API lives.
    command: 'npm run dev -- --port 5173 --strictPort',
    cwd: '../../apps/portal',
    url: 'http://localhost:5173',
    reuseExistingServer: true,
    timeout: 120_000,
    // Through the dev proxy, not cross-origin. VITE_API_BASE_URL would send
    // the browser straight at the deployed API, which refuses a preflight
    // from localhost with a 403 — and the portal used to report that as a
    // wrong password. `/api` is same-origin, which is what production is too.
    env: {
      VSP_API_PROXY_TARGET:
        process.env.VSP_API_BASE_URL ?? 'https://vps-api.vnteki.com',
    },
  },
});
