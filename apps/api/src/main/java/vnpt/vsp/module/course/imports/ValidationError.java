package vnpt.vsp.module.course.imports;

/**
 * Structured validation error for import operations.
 * Per Story 3.4 AC-2: actionable errors per feature.
 */
public class ValidationError {

    private final int featureIndex;
    private final String geometryType;
    private final String field;
    private final ValidationErrorCode code;
    private final String message;
    private final String severity;

    public ValidationError(int featureIndex, String geometryType, String field,
                         ValidationErrorCode code, String message, String severity) {
        this.featureIndex = featureIndex;
        this.geometryType = geometryType;
        this.field = field;
        this.code = code;
        this.message = message;
        this.severity = severity;
    }

    public int getFeatureIndex() { return featureIndex; }
    public String getGeometryType() { return geometryType; }
    public String getField() { return field; }
    public ValidationErrorCode getCode() { return code; }
    public String getMessage() { return message; }
    public String getSeverity() { return severity; }

    @Override
    public String toString() {
        return String.format("ValidationError[index=%d, type=%s, field=%s, code=%s, msg=%s]",
            featureIndex, geometryType, field, code, message);
    }
}
