package vnpt.vsp.module.role.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request DTO for verifying a TOTP code during admin login or MFA verification.
 */
public class VerifyMfaRequest {

    @NotBlank
    private String totpCode;

    public VerifyMfaRequest() {}

    public VerifyMfaRequest(String totpCode) {
        this.totpCode = totpCode;
    }

    public String getTotpCode() {
        return totpCode;
    }

    public void setTotpCode(String totpCode) {
        this.totpCode = totpCode;
    }
}
