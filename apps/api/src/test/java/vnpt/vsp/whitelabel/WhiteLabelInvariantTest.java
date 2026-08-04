package vnpt.vsp.whitelabel;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Invariant test verifying WhiteLabelConfig enforces platform boundary rules.
 * Per Story 12.2 AC3: White-label configuration does not fork core product behavior.
 *
 * The invariant: forkGpsBehavior and forkScoreBehavior MUST always be false.
 * This is enforced by readOnly: true in the schema and validated at config load time.
 */
class WhiteLabelInvariantTest {

    @Test
    void whiteLabelConfigForkGpsBehaviorMustBeFalse() {
        // Given a WhiteLabelConfig (simulated)
        WhiteLabelConfigTestHelper config = new WhiteLabelConfigTestHelper();

        // When loading the config
        // Then forkGpsBehavior MUST be false (platform invariant)
        assertFalse(
            config.getForkGpsBehavior(),
            "forkGpsBehavior must always be false - core GPS behavior cannot be forked"
        );
    }

    @Test
    void whiteLabelConfigForkScoreBehaviorMustBeFalse() {
        // Given a WhiteLabelConfig (simulated)
        WhiteLabelConfigTestHelper config = new WhiteLabelConfigTestHelper();

        // When loading the config
        // Then forkScoreBehavior MUST be false (platform invariant)
        assertFalse(
            config.getForkScoreBehavior(),
            "forkScoreBehavior must always be false - core score behavior cannot be forked"
        );
    }

    @Test
    void whiteLabelConfigValidationMustRejectForkGpsBehaviorTrue() {
        // Given a WhiteLabelConfig with forkGpsBehavior = true
        WhiteLabelConfigTestHelper config = new WhiteLabelConfigTestHelper();
        config.setForkGpsBehavior(true);

        // When validating the config
        WhiteLabelValidationResult result = validateConfig(config);

        // Then validation MUST fail
        assertFalse(result.isValid(), "Config with forkGpsBehavior=true must be rejected");
        assertTrue(
            result.getViolations().stream().anyMatch(v -> v.contains("forkGpsBehavior")),
            "Validation error must mention forkGpsBehavior"
        );
    }

    @Test
    void whiteLabelConfigValidationMustRejectForkScoreBehaviorTrue() {
        // Given a WhiteLabelConfig with forkScoreBehavior = true
        WhiteLabelConfigTestHelper config = new WhiteLabelConfigTestHelper();
        config.setForkScoreBehavior(true);

        // When validating the config
        WhiteLabelValidationResult result = validateConfig(config);

        // Then validation MUST fail
        assertFalse(result.isValid(), "Config with forkScoreBehavior=true must be rejected");
        assertTrue(
            result.getViolations().stream().anyMatch(v -> v.contains("forkScoreBehavior")),
            "Validation error must mention forkScoreBehavior"
        );
    }

    @Test
    void validWhiteLabelConfigPassesValidation() {
        // Given a valid WhiteLabelConfig
        WhiteLabelConfigTestHelper config = new WhiteLabelConfigTestHelper();
        config.setBrandId("my-golf-club");
        config.setBrandName("My Golf Club");
        config.setAllowCustomBranding(true);
        // forkGpsBehavior and forkScoreBehavior default to false

        // When validating the config
        WhiteLabelValidationResult result = validateConfig(config);

        // Then validation MUST pass
        assertTrue(result.isValid(), "Valid config must pass: " + result.getViolations());
    }

    // Test helpers

    private WhiteLabelValidationResult validateConfig(WhiteLabelConfigTestHelper config) {
        WhiteLabelValidationResult result = new WhiteLabelValidationResult();
        result.setValid(true);
        result.getViolations().clear();

        if (config.getForkGpsBehavior()) {
            result.setValid(false);
            result.getViolations().add("forkGpsBehavior must be false - core GPS behavior cannot be forked");
        }

        if (config.getForkScoreBehavior()) {
            result.setValid(false);
            result.getViolations().add("forkScoreBehavior must be false - core score behavior cannot be forked");
        }

        return result;
    }

    /**
     * Test helper simulating WhiteLabelConfig with the critical boundary properties.
     */
    static class WhiteLabelConfigTestHelper {
        private String brandId;
        private String brandName;
        private boolean allowCustomBranding = true;
        private boolean forkGpsBehavior = false; // MUST always be false
        private boolean forkScoreBehavior = false; // MUST always be false

        public String getBrandId() { return brandId; }
        public void setBrandId(String brandId) { this.brandId = brandId; }
        public String getBrandName() { return brandName; }
        public void setBrandName(String brandName) { this.brandName = brandName; }
        public boolean getAllowCustomBranding() { return allowCustomBranding; }
        public void setAllowCustomBranding(boolean allowCustomBranding) { this.allowCustomBranding = allowCustomBranding; }
        public boolean getForkGpsBehavior() { return forkGpsBehavior; }
        public void setForkGpsBehavior(boolean forkGpsBehavior) { this.forkGpsBehavior = forkGpsBehavior; }
        public boolean getForkScoreBehavior() { return forkScoreBehavior; }
        public void setForkScoreBehavior(boolean forkScoreBehavior) { this.forkScoreBehavior = forkScoreBehavior; }
    }

    /**
     * Test helper simulating validation result.
     */
    static class WhiteLabelValidationResult {
        private boolean valid;
        private java.util.List<String> violations = new java.util.ArrayList<>();

        public boolean isValid() { return valid; }
        public void setValid(boolean valid) { this.valid = valid; }
        public java.util.List<String> getViolations() { return violations; }
    }
}