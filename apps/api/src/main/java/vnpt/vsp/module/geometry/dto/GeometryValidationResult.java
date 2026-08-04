package vnpt.vsp.module.geometry.dto;

import java.util.ArrayList;
import java.util.List;

/**
 * Result DTO for geometry validation.
 * Per Story 8.2 Slice 6.
 */
public class GeometryValidationResult {

    private Long courseId;
    private boolean valid;
    private int totalChecked;
    private int validCount;
    private int invalidCount;
    private final List<FeatureValidationError> errors = new ArrayList<>();

    public GeometryValidationResult() {
    }

    public GeometryValidationResult(Long courseId, boolean valid, int totalChecked,
                                     int validCount, int invalidCount) {
        this.courseId = courseId;
        this.valid = valid;
        this.totalChecked = totalChecked;
        this.validCount = validCount;
        this.invalidCount = invalidCount;
    }

    public void addError(FeatureValidationError error) {
        this.errors.add(error);
    }

    public boolean isValid() {
        return valid;
    }

    public void setValid(boolean valid) {
        this.valid = valid;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public int getTotalChecked() {
        return totalChecked;
    }

    public void setTotalChecked(int totalChecked) {
        this.totalChecked = totalChecked;
    }

    public int getValidCount() {
        return validCount;
    }

    public void setValidCount(int validCount) {
        this.validCount = validCount;
    }

    public int getInvalidCount() {
        return invalidCount;
    }

    public void setInvalidCount(int invalidCount) {
        this.invalidCount = invalidCount;
    }

    public List<FeatureValidationError> getErrors() {
        return errors;
    }

    /**
     * Represents a single feature validation error.
     */
    public static class FeatureValidationError {

        private String featureUuid;
        private String errorCode;
        private String errorMessage;
        private String layerType;
        private Long featureId;

        public FeatureValidationError() {
        }

        public FeatureValidationError(String featureUuid, String errorCode,
                                       String errorMessage, String layerType) {
            this.featureUuid = featureUuid;
            this.errorCode = errorCode;
            this.errorMessage = errorMessage;
            this.layerType = layerType;
        }

        public String getFeatureUuid() {
            return featureUuid;
        }

        public void setFeatureUuid(String featureUuid) {
            this.featureUuid = featureUuid;
        }

        public String getErrorCode() {
            return errorCode;
        }

        public void setErrorCode(String errorCode) {
            this.errorCode = errorCode;
        }

        public String getErrorMessage() {
            return errorMessage;
        }

        public void setErrorMessage(String errorMessage) {
            this.errorMessage = errorMessage;
        }

        public String getLayerType() {
            return layerType;
        }

        public void setLayerType(String layerType) {
            this.layerType = layerType;
        }

        public Long getFeatureId() {
            return featureId;
        }

        public void setFeatureId(Long featureId) {
            this.featureId = featureId;
        }
    }
}
