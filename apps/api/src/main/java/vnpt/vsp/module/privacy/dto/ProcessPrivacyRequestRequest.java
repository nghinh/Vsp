package vnpt.vsp.module.privacy.dto;

import jakarta.validation.constraints.NotNull;
import org.hibernate.validator.constraints.Length;

/**
 * Request DTO for processing (completing or rejecting) a privacy request.
 * Per Story 2.5 AC-3: auditable processing by admin.
 */
public class ProcessPrivacyRequestRequest {

    @NotNull(message = "Status is required")
    private String status;

    @Length(max = 500, message = "Rejection reason must be at most 500 characters")
    private String rejectionReason;

    public ProcessPrivacyRequestRequest() {
    }

    public ProcessPrivacyRequestRequest(String status, String rejectionReason) {
        this.status = status;
        this.rejectionReason = rejectionReason;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getRejectionReason() {
        return rejectionReason;
    }

    public void setRejectionReason(String rejectionReason) {
        this.rejectionReason = rejectionReason;
    }
}
