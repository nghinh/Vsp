package vnpt.vsp.module.course.dto;

import java.util.ArrayList;
import java.util.List;

/**
 * Response from pre-publish validation endpoint.
 * Per Story 8.3 AC-1.
 */
public class ValidationResponse {

    public enum Result {
        VALID,
        GEOMETRY_INVALID,
        METADATA_MISSING,
        LICENSE_MISSING,
        QUALITY_INSUFFICIENT,
        SOURCE_MISSING,
        VALIDATION_ERROR
    }

    private Long versionId;
    private Result result;
    private List<ValidationError> errors = new ArrayList<>();
    private List<ValidationWarning> warnings = new ArrayList<>();

    public ValidationResponse() {}

    public ValidationResponse(Long versionId, Result result) {
        this.versionId = versionId;
        this.result = result;
    }

    public Long getVersionId() { return versionId; }
    public void setVersionId(Long versionId) { this.versionId = versionId; }
    public Result getResult() { return result; }
    public void setResult(Result result) { this.result = result; }
    public List<ValidationError> getErrors() { return errors; }
    public void setErrors(List<ValidationError> errors) { this.errors = errors; }
    public List<ValidationWarning> getWarnings() { return warnings; }
    public void setWarnings(List<ValidationWarning> warnings) { this.warnings = warnings; }

    public void addError(ValidationError error) { this.errors.add(error); }
    public void addWarning(ValidationWarning warning) { this.warnings.add(warning); }

    public boolean hasErrors() { return !errors.isEmpty(); }
}
