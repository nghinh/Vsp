package vnpt.vsp.module.operations.dto;

import java.time.Instant;

/**
 * Shared data quality metadata DTO for operations module DTOs.
 * Mirrors DataQualityMetadata embedded entity fields.
 */
public class DataQualityDto {

    private String source;
    private String accuracyClass;
    private String verificationStatus;
    private Instant createdAt;
    private Instant updatedAt;

    public DataQualityDto() {}

    public DataQualityDto(String source, String accuracyClass, String verificationStatus,
                         Instant createdAt, Instant updatedAt) {
        this.source = source;
        this.accuracyClass = accuracyClass;
        this.verificationStatus = verificationStatus;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    // Getters and Setters

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }

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

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
