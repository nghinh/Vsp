package vnpt.vsp.module.course.dto;

/**
 * DTO for import commit result.
 * Per Story 3.4 AC-3: imported data remains draft until reviewed and published.
 */
public class ImportResultDto {

    private Long courseId;
    private Long dataVersionId;
    private Integer versionNumber;
    private int featureCount;
    private String status;

    public ImportResultDto() {}

    public ImportResultDto(Long courseId, Long dataVersionId, Integer versionNumber,
                          int featureCount, String status) {
        this.courseId = courseId;
        this.dataVersionId = dataVersionId;
        this.versionNumber = versionNumber;
        this.featureCount = featureCount;
        this.status = status;
    }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }
    public Long getDataVersionId() { return dataVersionId; }
    public void setDataVersionId(Long dataVersionId) { this.dataVersionId = dataVersionId; }
    public Integer getVersionNumber() { return versionNumber; }
    public void setVersionNumber(Integer versionNumber) { this.versionNumber = versionNumber; }
    public int getFeatureCount() { return featureCount; }
    public void setFeatureCount(int featureCount) { this.featureCount = featureCount; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
}
