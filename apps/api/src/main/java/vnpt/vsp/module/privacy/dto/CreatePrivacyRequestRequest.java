package vnpt.vsp.module.privacy.dto;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

/**
 * Request DTO for creating a privacy request.
 * Per Story 2.5 AC-3: supports DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION.
 */
public class CreatePrivacyRequestRequest {

    @NotNull(message = "Request type is required")
    private String requestType;

    private UUID targetRoundId;

    public CreatePrivacyRequestRequest() {
    }

    public CreatePrivacyRequestRequest(String requestType, UUID targetRoundId) {
        this.requestType = requestType;
        this.targetRoundId = targetRoundId;
    }

    public String getRequestType() {
        return requestType;
    }

    public void setRequestType(String requestType) {
        this.requestType = requestType;
    }

    public UUID getTargetRoundId() {
        return targetRoundId;
    }

    public void setTargetRoundId(UUID targetRoundId) {
        this.targetRoundId = targetRoundId;
    }
}
