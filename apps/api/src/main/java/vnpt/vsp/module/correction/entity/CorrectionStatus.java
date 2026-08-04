package vnpt.vsp.module.correction.entity;

/**
 * Status values for a course correction submission.
 *
 * <p>State machine:
 * <ul>
 *   <li>{@code PENDING} — newly submitted, awaiting review</li>
 *   <li>{@code IN_REVIEW} — an admin has opened the correction for review</li>
 *   <li>{@code APPROVED} — terminal; correction accepted and applied</li>
 *   <li>{@code REJECTED} — terminal; correction declined</li>
 *   <li>{@code INFO_REQUESTED} — terminal; reviewer asked reporter for more info</li>
 *   <li>{@code CONVERTED_TO_DRAFT} — terminal; linked to geometry editor draft</li>
 * </ul>
 *
 * Per Story 9.2 AC-3 and Slice Plan §Slice A.
 */
public enum CorrectionStatus {
    PENDING,
    IN_REVIEW,
    APPROVED,
    REJECTED,
    INFO_REQUESTED,
    CONVERTED_TO_DRAFT
}
