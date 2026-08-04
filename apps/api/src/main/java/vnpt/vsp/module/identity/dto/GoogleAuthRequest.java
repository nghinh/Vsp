package vnpt.vsp.module.identity.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request DTO for Google OAuth authentication.
 * The client sends the Google ID token obtained from the Google Sign-In SDK.
 */
public class GoogleAuthRequest {

    @NotBlank(message = "Google ID token is required")
    private String idToken;

    private String displayName;

    public GoogleAuthRequest() {
    }

    public GoogleAuthRequest(String idToken) {
        this.idToken = idToken;
    }

    public String getIdToken() {
        return idToken;
    }

    public void setIdToken(String idToken) {
        this.idToken = idToken;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }
}
