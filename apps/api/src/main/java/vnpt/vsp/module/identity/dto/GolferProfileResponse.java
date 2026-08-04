package vnpt.vsp.module.identity.dto;

/**
 * Response DTO for the /auth/me endpoint.
 */
public class GolferProfileResponse {

    private Long id;
    private String phone;
    private String email;
    private String displayName;
    private String status;
    private boolean verified;
    private String createdAt;

    public GolferProfileResponse() {
    }

    public static Builder builder() {
        return new Builder();
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public boolean isVerified() {
        return verified;
    }

    public void setVerified(boolean verified) {
        this.verified = verified;
    }

    public String getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }

    public static class Builder {
        private final GolferProfileResponse response = new GolferProfileResponse();

        public Builder id(Long id) {
            response.id = id;
            return this;
        }

        public Builder phone(String phone) {
            response.phone = phone;
            return this;
        }

        public Builder email(String email) {
            response.email = email;
            return this;
        }

        public Builder displayName(String displayName) {
            response.displayName = displayName;
            return this;
        }

        public Builder status(String status) {
            response.status = status;
            return this;
        }

        public Builder verified(boolean verified) {
            response.verified = verified;
            return this;
        }

        public Builder createdAt(String createdAt) {
            response.createdAt = createdAt;
            return this;
        }

        public GolferProfileResponse build() {
            return response;
        }
    }
}
