package vnpt.vsp.module.course.dto;

import java.util.List;

/**
 * DTO for detailed validation report.
 * Per Story 3.4 AC-2: actionable errors per feature.
 */
public class ValidationReportDto {

    private int totalFeatures;
    private int validCount;
    private int errorCount;
    private List<ValidationErrorDto> errors;
    private int page;
    private int size;
    private long totalElements;

    public ValidationReportDto() {}

    public ValidationReportDto(int totalFeatures, int validCount, int errorCount,
                              List<ValidationErrorDto> errors, int page, int size, long totalElements) {
        this.totalFeatures = totalFeatures;
        this.validCount = validCount;
        this.errorCount = errorCount;
        this.errors = errors;
        this.page = page;
        this.size = size;
        this.totalElements = totalElements;
    }

    public int getTotalFeatures() { return totalFeatures; }
    public void setTotalFeatures(int totalFeatures) { this.totalFeatures = totalFeatures; }
    public int getValidCount() { return validCount; }
    public void setValidCount(int validCount) { this.validCount = validCount; }
    public int getErrorCount() { return errorCount; }
    public void setErrorCount(int errorCount) { this.errorCount = errorCount; }
    public List<ValidationErrorDto> getErrors() { return errors; }
    public void setErrors(List<ValidationErrorDto> errors) { this.errors = errors; }
    public int getPage() { return page; }
    public void setPage(int page) { this.page = page; }
    public int getSize() { return size; }
    public void setSize(int size) { this.size = size; }
    public long getTotalElements() { return totalElements; }
    public void setTotalElements(long totalElements) { this.totalElements = totalElements; }
}
