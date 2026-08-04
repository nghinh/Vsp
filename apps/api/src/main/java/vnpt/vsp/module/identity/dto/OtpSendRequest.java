package vnpt.vsp.module.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Request DTO for sending OTP codes.
 */
public class OtpSendRequest {

    @NotBlank(message = "Phone or email is required")
    private String identifier;  // phone number or email address

    @NotBlank(message = "OTP type is required")
    @Pattern(regexp = "^(PHONE_VERIFY|EMAIL_VERIFY|PASSWORD_RECOVERY)$", message = "Invalid OTP type")
    private String type;

    public String getIdentifier() {
        return identifier;
    }

    public void setIdentifier(String identifier) {
        this.identifier = identifier;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }
}
