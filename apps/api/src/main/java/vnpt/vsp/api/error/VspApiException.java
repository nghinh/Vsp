package vnpt.vsp.api.error;

import java.util.Map;
import java.util.Objects;

/**
 * Runtime exception carrying a stable {@link VspErrorCode}, an optional field name
 * for field-level validation errors, and an optional map of extra details.
 */
public class VspApiException extends RuntimeException {

    private final VspErrorCode errorCode;
    private final String field;
    private final Map<String, Object> details;

    public VspApiException(VspErrorCode errorCode) {
        super(errorCode.getDefaultMessage());
        this.errorCode = Objects.requireNonNull(errorCode, "errorCode must not be null");
        this.field = null;
        this.details = null;
    }

    public VspApiException(VspErrorCode errorCode, String field) {
        super(errorCode.getDefaultMessage());
        this.errorCode = Objects.requireNonNull(errorCode, "errorCode must not be null");
        this.field = field;
        this.details = null;
    }

    public VspApiException(VspErrorCode errorCode, String field, Map<String, Object> details) {
        super(errorCode.getDefaultMessage());
        this.errorCode = Objects.requireNonNull(errorCode, "errorCode must not be null");
        this.field = field;
        this.details = details;
    }

    public VspApiException(VspErrorCode errorCode, Map<String, Object> details) {
        super(errorCode.getDefaultMessage());
        this.errorCode = Objects.requireNonNull(errorCode, "errorCode must not be null");
        this.field = null;
        this.details = details;
    }

    public VspApiException(VspErrorCode errorCode, String message, String field, Map<String, Object> details) {
        super(message);
        this.errorCode = Objects.requireNonNull(errorCode, "errorCode must not be null");
        this.field = field;
        this.details = details;
    }

    public VspErrorCode getErrorCode() {
        return errorCode;
    }

    public String getField() {
        return field;
    }

    public Map<String, Object> getDetails() {
        return details;
    }

    /**
     * Convenience factory for field-level validation errors.
     */
    public static VspApiException forField(VspErrorCode code, String field) {
        return new VspApiException(code, field);
    }

    /**
     * Convenience factory for field-level validation errors with extra details.
     */
    public static VspApiException forField(VspErrorCode code, String field, Map<String, Object> details) {
        return new VspApiException(code, field, details);
    }

    /**
     * Convenience factory for global errors with extra details.
     */
    public static VspApiException withDetails(VspErrorCode code, Map<String, Object> details) {
        return new VspApiException(code, details);
    }
}
