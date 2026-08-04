package vnpt.vsp.module.identity.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request DTO for initiating password recovery.
 */
public class PasswordRecoverRequest {

    @NotBlank(message = "Phone or email is required")
    private String identifier;  // phone number or email address

    public String getIdentifier() {
        return identifier;
    }

    public void setIdentifier(String identifier) {
        this.identifier = identifier;
    }
}
