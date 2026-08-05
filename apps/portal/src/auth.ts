/**
 * Portal auth/session helpers.
 *
 * The portal shell injects an auth token + operator roles into every page via
 * router `props`. In production these come from the login/MFA flow (mockup 25)
 * and are persisted in localStorage; in dev they fall back to a demo token so
 * the routed pages render against the dev API (or their built-in mock data).
 */

const TOKEN_KEY = "vsp_portal_token";
const ROLES_KEY = "vsp_portal_roles";

const DEV_TOKEN = "dev-portal-token";
const DEFAULT_ROLES = ["COURSE_ADMIN", "SUPER_ADMIN"];

export function getAuthToken(): string {
  try {
    return localStorage.getItem(TOKEN_KEY) ?? DEV_TOKEN;
  } catch {
    return DEV_TOKEN;
  }
}

export function getUserRoles(): string[] {
  try {
    const raw = localStorage.getItem(ROLES_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return parsed as string[];
    }
  } catch {
    /* ignore malformed storage */
  }
  return [...DEFAULT_ROLES];
}
