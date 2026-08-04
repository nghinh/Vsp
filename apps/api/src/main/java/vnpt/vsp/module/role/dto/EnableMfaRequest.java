package vnpt.vsp.module.role.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request DTO for enabling MFA on an admin account.
 * The totpCode is the current TOTP code used to verify the secret is correct.
 */
public class EnableMfaRequest {

    @NotBlank
    private String totpCode;

    public EnableMfaRequest() {}

    public EnableMfaRequest(String totpCode) {
        this.totpCode = totpCode;
    }

    public String getTotpCode() {
        return totpCode;
    }

    public void setTotpCode(String totpCode) {
        this.totpCode = totpCode;
    }
}
