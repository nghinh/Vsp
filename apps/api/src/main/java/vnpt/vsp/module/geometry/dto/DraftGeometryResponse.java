package vnpt.vsp.module.geometry.dto;

import vnpt.vsp.module.geometry.LayerType;

import java.util.List;

/**
 * Response DTO for fetching all draft geometry for a course.
 * Per Story 8.2 Slice 6.
 */
public class DraftGeometryResponse {

    private Long courseId;
    private int totalFeatures;
    private int validFeatures;
    private int invalidFeatures;
    private List<DraftFeatureResponse> features;

    public DraftGeometryResponse() {
    }

    public DraftGeometryResponse(Long courseId, List<DraftFeatureResponse> features) {
        this.courseId = courseId;
        this.features = features;
        this.totalFeatures = features != null ? features.size() : 0;
        this.validFeatures = (int) features.stream().filter(DraftFeatureResponse::isValid).count();
        this.invalidFeatures = totalFeatures - validFeatures;
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public int getTotalFeatures() {
        return totalFeatures;
    }

    public void setTotalFeatures(int totalFeatures) {
        this.totalFeatures = totalFeatures;
    }

    public int getValidFeatures() {
        return validFeatures;
    }

    public void setValidFeatures(int validFeatures) {
        this.validFeatures = validFeatures;
    }

    public int getInvalidFeatures() {
        return invalidFeatures;
    }

    public void setInvalidFeatures(int invalidFeatures) {
        this.invalidFeatures = invalidFeatures;
    }

    public List<DraftFeatureResponse> getFeatures() {
        return features;
    }

    public void setFeatures(List<DraftFeatureResponse> features) {
        this.features = features;
    }
}
