/**
 * The six role names, spelled as the API spells them, and which of them each
 * area of the portal is for.
 *
 * These lists mirror the `@PreAuthorize` on the controllers behind each area.
 * They decide what is *shown* — the navigation an operator sees, and which
 * routes resolve. They decide nothing about what is *allowed*: every request
 * the portal makes is authorised again by the API against roles it reads from
 * the database, and a list here that is wrong in the permissive direction
 * produces a page full of 403s, not access.
 *
 * They are worth keeping accurate anyway. A portal that offers an auditor a
 * "publish version" button teaches them to distrust the portal.
 */

export const ROLE = {
  SUPER_ADMIN: 'SUPER_ADMIN',
  COURSE_ADMIN: 'COURSE_ADMIN',
  GREENKEEPER: 'GREENKEEPER',
  TOURNAMENT_DIRECTOR: 'TOURNAMENT_DIRECTOR',
  CADDIE_MASTER: 'CADDIE_MASTER',
  AUDITOR: 'AUDITOR',
} as const;

export type RoleName = (typeof ROLE)[keyof typeof ROLE];

/** FacilityAdminController, CourseAdminController, HoleAdminController, TeeSetAdminController. */
export const COURSE_ROLES: readonly RoleName[] = [ROLE.COURSE_ADMIN, ROLE.SUPER_ADMIN];

/** PinPositionController, GreenConditionController, CourseConditionController. */
export const GREENKEEPING_ROLES: readonly RoleName[] = [
  ROLE.GREENKEEPER,
  ROLE.COURSE_ADMIN,
  ROLE.SUPER_ADMIN,
];

/** CorrectionController. */
export const CORRECTION_ROLES: readonly RoleName[] = [
  ROLE.COURSE_ADMIN,
  ROLE.GREENKEEPER,
  ROLE.SUPER_ADMIN,
];

/** DataQualityController. */
export const DATA_QUALITY_ROLES: readonly RoleName[] = [
  ROLE.SUPER_ADMIN,
  ROLE.COURSE_ADMIN,
  ROLE.AUDITOR,
];

/** TournamentController and its siblings. */
export const TOURNAMENT_ROLES: readonly RoleName[] = [
  ROLE.TOURNAMENT_DIRECTOR,
  ROLE.SUPER_ADMIN,
];

/** RoleController, AdminMarketController, DataLicenseController. */
export const SUPER_ADMIN_ONLY: readonly RoleName[] = [ROLE.SUPER_ADMIN];
