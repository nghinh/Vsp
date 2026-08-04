package vnpt.vsp.module.course.dto;

import java.util.List;
import java.util.Map;

/**
 * DTO for import preview response.
 * Per Story 3.4 AC-2: actionable errors per feature.
 */
public class ImportPreviewDto {

    private int totalFeatures;
    private int validCount;
    private int errorCount;
    private Map<String, Integer> geometryTypeBreakdown;
    private String errorSummary;
    private String previewToken;
    private List<ValidationErrorDto> errors;

    public ImportPreviewDto() {}

    public ImportPreviewDto(int totalFeatures, int validCount, int errorCount,
                           Map<String, Integer> geometryTypeBreakdown, String errorSummary,
                           String previewToken, List<ValidationErrorDto> errors) {
        this.totalFeatures = totalFeatures;
        this.validCount = validCount;
        this.errorCount = errorCount;
        this.geometryTypeBreakdown = geometryTypeBreakdown;
        this.errorSummary = errorSummary;
        this.previewToken = previewToken;
        this.errors = errors;
    }

    public int getTotalFeatures() { return totalFeatures; }
    public void setTotalFeatures(int totalFeatures) { this.totalFeatures = totalFeatures; }
    public int getValidCount() { return validCount; }
    public void setValidCount(int validCount) { this.validCount = validCount; }
    public int getErrorCount() { return errorCount; }
    public void setErrorCount(int errorCount) { this.errorCount = errorCount; }
    public Map<String, Integer> getGeometryTypeBreakdown() { return geometryTypeBreakdown; }
    public void setGeometryTypeBreakdown(Map<String, Integer> geometryTypeBreakdown) { this.geometryTypeBreakdown = geometryTypeBreakdown; }
    public String getErrorSummary() { return errorSummary; }
    public void setErrorSummary(String errorSummary) { this.errorSummary = errorSummary; }
    public String getPreviewToken() { return previewToken; }
    public void setPreviewToken(String previewToken) { this.previewToken = previewToken; }
    public List<ValidationErrorDto> getErrors() { return errors; }
    public void setErrors(List<ValidationErrorDto> errors) { this.errors = errors; }
}
