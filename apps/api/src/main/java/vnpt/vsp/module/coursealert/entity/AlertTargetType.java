package vnpt.vsp.module.coursealert.entity;

/**
 * Enumerates the target scope for a course alert.
 * Per Story 8.6 AC-1: facility, course, hole, flight, or group targeting.
 */
public enum AlertTargetType {
    FACILITY,
    COURSE,
    HOLE,
    FLIGHT,
    GROUP
}
