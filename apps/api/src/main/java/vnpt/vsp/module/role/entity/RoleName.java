package vnpt.vsp.module.role.entity;

/**
 * Enumerates the 6 RBAC roles for the Course Operations Portal.
 * Per Story 2.5 AC-1: RBAC supports super admin, course admin, greenkeeper,
 * tournament director, caddie master, and auditor.
 * Per Architecture §10 Portal Architecture.
 */
public enum RoleName {
    SUPER_ADMIN,
    COURSE_ADMIN,
    GREENKEEPER,
    TOURNAMENT_DIRECTOR,
    CADDIE_MASTER,
    AUDITOR
}
