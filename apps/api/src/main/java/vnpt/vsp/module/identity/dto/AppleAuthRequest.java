package vnpt.vsp.module.identity.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request DTO for Apple Sign-In authentication.
 * The client sends the Apple identity token and authorization code obtained from the
 * Apple Sign-In SDK.
 */
public class AppleAuthRequest {

    @NotBlank(message = "Apple identity token is required")
    private String idToken;

    private String authorizationCode;

    private String displayName;

    public AppleAuthRequest() {
    }

    public AppleAuthRequest(String idToken) {
        this.idToken = idToken;
    }

    public String getIdToken() {
        return idToken;
    }

    public void setIdToken(String idToken) {
        this.idToken = idToken;
    }

    public String getAuthorizationCode() {
        return authorizationCode;
    }

    public void setAuthorizationCode(String authorizationCode) {
        this.authorizationCode = authorizationCode;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }
}
