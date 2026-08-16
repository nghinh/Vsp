import type { Page, ConsoleMessage } from '@playwright/test';

/**
 * What the browser objected to while a page was open.
 *
 * Lives outside the spec files because Playwright refuses to let one spec
 * import another — and because a page that throws while rendering still shows
 * a header and a nav, so a human clicking round sees a screen that is merely
 * empty and moves on. The browser knows better.
 *
 * A failure is an uncaught exception, a console error, or a 5xx from our own
 * API. Not: a 401 on a page this account may not see, a 404 for a record that
 * is gone, or anything from a tile server, which is not ours to fix.
 */
/** Noise from outside our own code, which a portal bug cannot cause. */
const IGNORED = [
  /maplibre/i,
  /tile/i,
  /favicon/i,
  /ResizeObserver loop/i,
  /Download the Vue Devtools/i,
];

function ignored(text: string): boolean {
  return IGNORED.some((pattern) => pattern.test(text));
}

/** Everything the browser objected to while this page was open. */
export function watchForTrouble(page: Page) {
  const problems: string[] = [];

  page.on('console', (message: ConsoleMessage) => {
    if (message.type() !== 'error') return;
    const text = message.text();
    if (!ignored(text)) problems.push(`console: ${text}`);
  });
  page.on('pageerror', (error) => {
    if (!ignored(error.message)) problems.push(`uncaught: ${error.message}`);
  });
  page.on('response', (response) => {
    const url = response.url();
    if (response.status() >= 500 && !ignored(url)) {
      problems.push(`${response.status()} from ${new URL(url).pathname}`);
    }
  });

  return problems;
}
