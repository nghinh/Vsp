/**
 * Where the portal's API calls go.
 *
 * One place, because there were three. Across the API clients the default was
 * variously `/api`, `http://localhost:8080` and `https://api.vsp.local`:
 *
 *   /api                    correct — vite.config.ts proxies it to the API in
 *                           dev, and a reverse proxy serves it in production
 *   http://localhost:8080   works on a developer's machine and nowhere else
 *   https://api.vsp.local   resolves nowhere at all, in any environment
 *
 * Eight of the eleven clients used the third. `auth.ts` had already worked
 * this out and said so in a comment — sign-in worked and every admin screen
 * behind it failed on its first request — but the fix stayed in that one file.
 *
 * VITE_API_BASE_URL still overrides, for a deployment that serves the portal
 * and the API from different origins.
 */
export const API_BASE: string = import.meta.env.VITE_API_BASE_URL ?? '/api';
