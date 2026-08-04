package vnpt.vsp.module.course.dto;

/**
 * Data quality metadata DTO for course detail sub-entities.
 * Per Story 3.3 CD-BACK-1: AC-3 DataQualityBadge.
 * Carries accuracy class and verification status for mobile badge rendering.
 */
public class DataQualityDto {

    /** Accuracy class — A (RTK), B (licensed), C (satellite), D (community). */
    private String accuracyClass;

    /** Verification status — VERIFIED, PENDING_REVIEW, UNVERIFIED, REJECTED. */
    private String verificationStatus;

    public DataQualityDto() {}

    public DataQualityDto(String accuracyClass, String verificationStatus) {
        this.accuracyClass = accuracyClass;
        this.verificationStatus = verificationStatus;
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public String getAccuracyClass() {
        return accuracyClass;
    }

    public void setAccuracyClass(String accuracyClass) {
        this.accuracyClass = accuracyClass;
    }

    public String getVerificationStatus() {
        return verificationStatus;
    }

    public void setVerificationStatus(String verificationStatus) {
        this.verificationStatus = verificationStatus;
    }
}
