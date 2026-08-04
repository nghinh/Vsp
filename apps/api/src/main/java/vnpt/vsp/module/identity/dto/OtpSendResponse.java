package vnpt.vsp.module.identity.dto;

/**
 * Response DTO for OTP send operation.
 */
public class OtpSendResponse {

    private String message;
    private String expiresIn;  // Human-readable expiration time

    public OtpSendResponse() {
    }

    public OtpSendResponse(String message, String expiresIn) {
        this.message = message;
        this.expiresIn = expiresIn;
    }

    public static OtpSendResponse success() {
        return new OtpSendResponse("Verification code sent", "10 minutes");
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getExpiresIn() {
        return expiresIn;
    }

    public void setExpiresIn(String expiresIn) {
        this.expiresIn = expiresIn;
    }
}
