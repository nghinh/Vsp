package vnpt.vsp.module.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Request DTO for verifying OTP codes.
 */
public class OtpVerifyRequest {

    @NotBlank(message = "Phone or email is required")
    private String identifier;  // phone number or email address

    @NotBlank(message = "OTP code is required")
    @Size(min = 6, max = 6, message = "OTP code must be 6 digits")
    private String code;

    @NotBlank(message = "OTP type is required")
    @Pattern(regexp = "^(PHONE_VERIFY|EMAIL_VERIFY|PASSWORD_RECOVERY)$", message = "Invalid OTP type")
    private String type;

    public String getIdentifier() {
        return identifier;
    }

    public void setIdentifier(String identifier) {
        this.identifier = identifier;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }
}
