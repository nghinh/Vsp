package vnpt.vsp.module.geometry.dto;

import vnpt.vsp.module.geometry.LayerType;
import vnpt.vsp.module.geometry.entity.DraftGeometryFeature;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for a single draft geometry feature.
 * Per Story 8.2 Slice 6.
 */
public class DraftFeatureResponse {

    private Long id;
    private UUID featureUuid;
    private Long courseId;
    private Long holeId;
    private LayerType layerType;
    private String geometry;
    private boolean valid;
    private String validityMessage;
    private String externalFeatureId;
    private String featureName;
    private String publisher;
    private Integer version;
    private Instant createdAt;
    private Instant updatedAt;

    public static DraftFeatureResponse fromEntity(DraftGeometryFeature entity) {
        DraftFeatureResponse response = new DraftFeatureResponse();
        response.setId(entity.getId());
        response.setFeatureUuid(entity.getFeatureUuid());
        response.setCourseId(entity.getCourse().getId());
        response.setHoleId(entity.getHole() != null ? entity.getHole().getId() : null);
        response.setLayerType(entity.getLayerType());
        response.setGeometry(entity.getGeometry());
        response.setValid(entity.isValid());
        response.setValidityMessage(entity.getValidityMessage());
        response.setExternalFeatureId(entity.getExternalFeatureId());
        response.setFeatureName(entity.getFeatureName());
        response.setPublisher(entity.getMetadata().getPublisher());
        response.setVersion(entity.getMetadata().getVersion());
        response.setCreatedAt(entity.getCreatedAt());
        response.setUpdatedAt(entity.getUpdatedAt());
        return response;
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public UUID getFeatureUuid() {
        return featureUuid;
    }

    public void setFeatureUuid(UUID featureUuid) {
        this.featureUuid = featureUuid;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public Long getHoleId() {
        return holeId;
    }

    public void setHoleId(Long holeId) {
        this.holeId = holeId;
    }

    public LayerType getLayerType() {
        return layerType;
    }

    public void setLayerType(LayerType layerType) {
        this.layerType = layerType;
    }

    public String getGeometry() {
        return geometry;
    }

    public void setGeometry(String geometry) {
        this.geometry = geometry;
    }

    public boolean isValid() {
        return valid;
    }

    public void setValid(boolean valid) {
        this.valid = valid;
    }

    public String getValidityMessage() {
        return validityMessage;
    }

    public void setValidityMessage(String validityMessage) {
        this.validityMessage = validityMessage;
    }

    public String getExternalFeatureId() {
        return externalFeatureId;
    }

    public void setExternalFeatureId(String externalFeatureId) {
        this.externalFeatureId = externalFeatureId;
    }

    public String getFeatureName() {
        return featureName;
    }

    public void setFeatureName(String featureName) {
        this.featureName = featureName;
    }

    public String getPublisher() {
        return publisher;
    }

    public void setPublisher(String publisher) {
        this.publisher = publisher;
    }

    public Integer getVersion() {
        return version;
    }

    public void setVersion(Integer version) {
        this.version = version;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
