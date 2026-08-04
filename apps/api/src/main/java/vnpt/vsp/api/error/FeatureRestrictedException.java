package vnpt.vsp.api.error;

import java.util.Map;

/**
 * Exception thrown when a feature is restricted by tournament policy.
 *
 * Per tournament_policy.yaml FeatureRestrictedError contract.
 * Produces a 403 response with shape:
 * {
 *   "code": "FEATURE_RESTRICTED",
 *   "feature": "windAdjustmentEnabled",
 *   "message": "Wind adjustment is disabled in tournament mode"
 * }
 */
public class FeatureRestrictedException extends VspApiException {

    private final String feature;
    private final String message;

    public FeatureRestrictedException(String feature, String message) {
        super(VspErrorCode.FEATURE_RESTRICTED, message, null, Map.of(
                "code", "FEATURE_RESTRICTED",
                "feature", feature,
                "message", message
        ));
        this.feature = feature;
        this.message = message;
    }

    public String getFeature() {
        return feature;
    }

    public String getRestrictedMessage() {
        return message;
    }
}
