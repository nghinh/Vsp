package vnpt.vsp.module.course.imports;

/**
 * Error codes for import validation.
 * Per Story 3.4 AC-2: actionable error codes.
 */
public enum ValidationErrorCode {

    INVALID_COORDINATE("Invalid coordinate range"),
    INVALID_GEOMETRY("Invalid geometry (topology error)"),
    TYPE_MISMATCH("Geometry type does not match expected entity"),
    MISSING_ATTRIBUTE("Missing required attribute"),
    FK_NOT_FOUND("Referenced entity not found"),
    INVALID_SRID("Coordinate is not WGS84 (SRID 4326)");

    private final String description;

    ValidationErrorCode(String description) {
        this.description = description;
    }

    public String getDescription() { return description; }
}
