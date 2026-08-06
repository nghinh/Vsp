package vnpt.vsp.module.course.dto;

import java.math.BigDecimal;

/**
 * Data freshness metadata returned in every search result.
 * Per Story 3.2 SD-BACK-1: AC-3 (verification, data freshness, download, update state).
 */
public class DataFreshnessDto {

    /** When this data version was published. */
    private String publishedAt;

    /** Version number of the latest published data version. */
    private Integer versionNumber;

    /** Entity that published this data. */
    private String publisher;

    /** Verification status (VERIFIED, PENDING_REVIEW, UNVERIFIED, REJECTED). */
    private String verificationStatus;

    /**
     * Accuracy class of this data version — A_RTK_SURVEYED, B_LICENSED_PROVIDER,
     * C_VERIFIED_SATELLITE or D_UNVERIFIED_COMMUNITY.
     *
     * <p>Sent because verification status alone does not tell a golfer how the
     * coordinates were obtained. A row can be marked VERIFIED and still be
     * class D, and the client has to be able to refuse to call that surveyed.</p>
     */
    private String accuracyClass;

    /** When the data was last verified by an authoritative source. */
    private String lastVerifiedAt;

    public DataFreshnessDto() {}

    public DataFreshnessDto(String publishedAt, Integer versionNumber, String publisher,
                            String verificationStatus, String lastVerifiedAt) {
        this.publishedAt = publishedAt;
        this.versionNumber = versionNumber;
        this.publisher = publisher;
        this.verificationStatus = verificationStatus;
        this.lastVerifiedAt = lastVerifiedAt;
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public String getPublishedAt() {
        return publishedAt;
    }

    public void setPublishedAt(String publishedAt) {
        this.publishedAt = publishedAt;
    }

    public Integer getVersionNumber() {
        return versionNumber;
    }

    public void setVersionNumber(Integer versionNumber) {
        this.versionNumber = versionNumber;
    }

    public String getPublisher() {
        return publisher;
    }

    public void setPublisher(String publisher) {
        this.publisher = publisher;
    }

    public String getVerificationStatus() {
        return verificationStatus;
    }

    public void setVerificationStatus(String verificationStatus) {
        this.verificationStatus = verificationStatus;
    }

    public String getAccuracyClass() {
        return accuracyClass;
    }

    public void setAccuracyClass(String accuracyClass) {
        this.accuracyClass = accuracyClass;
    }

    public String getLastVerifiedAt() {
        return lastVerifiedAt;
    }

    public void setLastVerifiedAt(String lastVerifiedAt) {
        this.lastVerifiedAt = lastVerifiedAt;
    }
}
