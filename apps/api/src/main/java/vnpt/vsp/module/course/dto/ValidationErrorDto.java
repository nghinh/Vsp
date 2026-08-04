package vnpt.vsp.module.course.dto;

/**
 * DTO for a single validation error per feature.
 * Per Story 3.4 AC-2: actionable errors with feature index, geometry type, field, code, message.
 */
public class ValidationErrorDto {

    private int featureIndex;
    private String geometryType;
    private String field;
    private String code;
    private String message;
    private String severity;

    public ValidationErrorDto() {}

    public ValidationErrorDto(int featureIndex, String geometryType, String field,
                             String code, String message, String severity) {
        this.featureIndex = featureIndex;
        this.geometryType = geometryType;
        this.field = field;
        this.code = code;
        this.message = message;
        this.severity = severity;
    }

    public int getFeatureIndex() { return featureIndex; }
    public void setFeatureIndex(int featureIndex) { this.featureIndex = featureIndex; }
    public String getGeometryType() { return geometryType; }
    public void setGeometryType(String geometryType) { this.geometryType = geometryType; }
    public String getField() { return field; }
    public void setField(String field) { this.field = field; }
    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
    public String getSeverity() { return severity; }
    public void setSeverity(String severity) { this.severity = severity; }
}
