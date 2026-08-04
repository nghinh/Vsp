package vnpt.vsp.module.course.entity;

/**
 * Accuracy class enum representing data source quality.
 * Per PRD Section 9.4: A (RTK surveyed) > B (Licensed provider) > C (Verified satellite) > D (Unverified community).
 */
public enum AccuracyClass {
    A_RTK_SURVEYED,
    B_LICENSED_PROVIDER,
    C_VERIFIED_SATELLITE,
    D_UNVERIFIED_COMMUNITY
}
